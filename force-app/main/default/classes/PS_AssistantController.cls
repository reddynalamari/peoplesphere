/**
 * PeopleSphere HR Assistant.
 *
 * 1. Natural-language HR analytics: a built-in intent engine turns common
 *    questions ("whose training expires this month?", "which department has
 *    the highest attrition?") into safe, sharing-aware SOQL. No setup needed.
 * 2. Policy copilot: answers grounded in active HR_Policy__c records. If a
 *    Named Credential called Claude_API exists, the question and the matching
 *    policy excerpts are sent to Claude for a written answer; otherwise the
 *    assistant returns the most relevant policy excerpts directly.
 *
 * The assistant only reads data and suggests; it never makes hiring, firing,
 * promotion or compensation decisions.
 */
public inherited sharing class PS_AssistantController {

    @TestVisible private static Boolean forceClaude = false;
    @TestVisible private static final String CLAUDE_MODEL = 'claude-opus-5-5';

    public class Answer {
        @AuraEnabled public String text;
        @AuraEnabled public String mode = 'text';         // text | table
        @AuraEnabled public List<String> columns = new List<String>();
        @AuraEnabled public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        @AuraEnabled public List<Map<String, String>> sources = new List<Map<String, String>>();
        @AuraEnabled public Boolean usedClaude = false;
        @AuraEnabled public String intent;
    }

    @AuraEnabled
    public static Answer ask(String question) {
        try {
            if (String.isBlank(question)) throw new PS_Util.PS_Exception('Ask me something about your people, policies or processes.');
            String q = question.toLowerCase().trim();
            Answer a = route(q, question);
            return a;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> suggestions() {
        return new List<String>{
            'Show employees whose certifications expire this month',
            'Which department has the highest attrition?',
            'List employees whose performance reviews are overdue',
            'Show onboarding processes pending for more than 7 days',
            'Who has Salesforce skills?',
            'Who is on leave today?',
            'Show open HR tickets that breached SLA',
            'Headcount by department',
            'What is the work from home policy?',
            'What is my leave balance?'
        };
    }

    /** Creates an HR ticket from an assistant conversation the user wants a human to handle. */
    @AuraEnabled
    public static HR_Ticket__c escalateToHr(String question, String assistantAnswer) {
        String body = 'Question asked to the HR Assistant:\n' + question +
            (String.isBlank(assistantAnswer) ? '' : '\n\nAssistant reply:\n' + assistantAnswer.abbreviate(3000));
        return PS_PortalController.raiseTicket(question.abbreviate(120), body, 'Medium', 'AI Assistant');
    }

    // ---------------------------------------------------------------------
    @TestVisible
    private static Answer route(String q, String original) {
        if (has(q, new List<String>{ 'my leave', 'leave balance', 'how many leaves' })) return myLeaveBalance();
        if (has(q, new List<String>{ 'certif' }) && has(q, new List<String>{ 'expir' })) return expiringCertifications(q);
        if (has(q, new List<String>{ 'training', 'course' }) && has(q, new List<String>{ 'overdue', 'pending', 'expir', 'mandatory' })) return overdueTraining();
        if (has(q, new List<String>{ 'review', 'appraisal' }) && has(q, new List<String>{ 'overdue', 'pending', 'late' })) return overdueReviews();
        if (has(q, new List<String>{ 'onboarding' }) && has(q, new List<String>{ 'pending', 'more than', 'open', 'delayed', 'stuck', 'days' })) return pendingOnboarding(q);
        if (has(q, new List<String>{ 'attrition', 'turnover', 'resign' })) return attritionByDepartment();
        if (has(q, new List<String>{ 'on leave', 'out of office', 'absent today' })) return onLeaveToday();
        if (has(q, new List<String>{ 'ticket' }) && has(q, new List<String>{ 'sla', 'breach', 'open', 'escalat' })) return openTickets(q);
        if (has(q, new List<String>{ 'headcount', 'how many employees', 'employee count', 'employees per', 'employees by' })) return headcount();
        if (has(q, new List<String>{ 'birthday' })) return birthdays();
        if (has(q, new List<String>{ 'new joiner', 'joined this month', 'joining this month', 'new hires' })) return newJoiners();
        if (has(q, new List<String>{ 'high risk', 'attrition risk', 'flight risk', 'at risk' })) return riskList();
        if (has(q, new List<String>{ 'laptop', 'asset' }) && has(q, new List<String>{ 'stock', 'available', 'free', 'unassigned' })) return assetsInStock();
        if (has(q, new List<String>{ 'open position', 'open role', 'vacanc', 'requisition', 'hiring' })) return openPositions();
        if (has(q, new List<String>{ 'skill', 'who knows', 'who has', 'expert', 'experience in', 'knows' })) return skillSearch(original);
        if (has(q, new List<String>{ 'help', 'what can you do' })) return help();
        return policyAnswer(original);
    }

    private static Boolean has(String q, List<String> words) {
        for (String w : words) if (q.contains(w)) return true;
        return false;
    }

    private static Answer table(String intent, String text, List<String> cols) {
        Answer a = new Answer();
        a.intent = intent;
        a.text = text;
        a.mode = 'table';
        a.columns = cols;
        return a;
    }

    // ---------------- analytics intents ---------------------------------
    private static Answer myLeaveBalance() {
        Employee__c me = PS_Util.currentEmployee();
        Answer a = new Answer();
        a.intent = 'leave_balance';
        if (me == null) { a.text = 'Your user is not linked to an employee record yet, so I cannot look up your balance.'; return a; }
        Integer pending = [SELECT COUNT() FROM Leave_Request__c WHERE Employee__c = :me.Id AND Status__c = 'Submitted'];
        a.text = 'Your current balances: Casual ' + me.Casual_Leave_Balance__c + ', Sick ' + me.Sick_Leave_Balance__c +
                 ', Earned ' + me.Earned_Leave_Balance__c + ' day(s).' + (pending > 0 ? ' You have ' + pending + ' request(s) awaiting approval.' : '');
        return a;
    }

    private static Answer expiringCertifications(String q) {
        Date until = q.contains('week') ? Date.today().addDays(7) : (q.contains('quarter') || q.contains('90') ? Date.today().addDays(90) : Date.today().toStartOfMonth().addMonths(1).addDays(-1));
        Answer a = table('expiring_certifications', '', new List<String>{ 'Employee', 'Certification', 'Expires on', 'Department' });
        for (Certification__c c : [SELECT Employee__c, Employee__r.Name, Name, Expires_On__c, Employee__r.Department__r.Name FROM Certification__c
                                   WHERE Expires_On__c >= TODAY AND Expires_On__c <= :until AND Employee__r.Status__c IN :PS_Util.ACTIVE_STATUSES
                                   ORDER BY Expires_On__c LIMIT 200]) {
            a.rows.add(row(c.Employee__c, new List<Object>{ c.Employee__r.Name, c.Name, c.Expires_On__c, c.Employee__r.Department__r?.Name }));
        }
        a.text = a.rows.size() + ' certification(s) expire by ' + until.format() + '.';
        return a;
    }

    private static Answer overdueTraining() {
        Answer a = table('overdue_training', '', new List<String>{ 'Employee', 'Course', 'Due date', 'Status' });
        for (Learning_Enrollment__c le : [SELECT Employee__c, Employee__r.Name, Course__r.Name, Due_Date__c, Status__c FROM Learning_Enrollment__c
                                          WHERE (Status__c = 'Overdue' OR (Status__c IN ('Assigned', 'In Progress') AND Due_Date__c < TODAY))
                                          AND Employee__r.Status__c IN :PS_Util.ACTIVE_STATUSES ORDER BY Due_Date__c LIMIT 200]) {
            a.rows.add(row(le.Employee__c, new List<Object>{ le.Employee__r.Name, le.Course__r.Name, le.Due_Date__c, le.Status__c }));
        }
        a.text = a.rows.isEmpty() ? 'Great news - no training is overdue.' : a.rows.size() + ' training assignment(s) are overdue.';
        return a;
    }

    private static Answer overdueReviews() {
        Answer a = table('overdue_reviews', '', new List<String>{ 'Employee', 'Cycle', 'Status', 'Due date', 'Reviewer' });
        for (Performance_Review__c r : [SELECT Employee__c, Employee__r.Name, Review_Cycle__c, Review_Year__c, Status__c, Due_Date__c, Reviewer__r.Name
                                        FROM Performance_Review__c WHERE Is_Overdue__c = true ORDER BY Due_Date__c LIMIT 200]) {
            a.rows.add(row(r.Employee__c, new List<Object>{ r.Employee__r.Name, r.Review_Cycle__c + ' ' + r.Review_Year__c, r.Status__c, r.Due_Date__c, r.Reviewer__r?.Name }));
        }
        a.text = a.rows.isEmpty() ? 'No performance reviews are overdue.' : a.rows.size() + ' performance review(s) are overdue.';
        return a;
    }

    private static Answer pendingOnboarding(String q) {
        Integer days = firstNumber(q, 7);
        Answer a = table('pending_onboarding', '', new List<String>{ 'Employee', 'Onboarding', 'Started', 'Days open', 'Completion %' });
        Date cutoff = Date.today().addDays(-days);
        for (Onboarding__c o : [SELECT Id, Name, Employee__r.Name, Start_Date__c, Days_Elapsed__c, Completion_Percent__c FROM Onboarding__c
                                WHERE Status__c IN ('Not Started', 'In Progress') AND Start_Date__c <= :cutoff ORDER BY Start_Date__c LIMIT 200]) {
            a.rows.add(row(o.Id, new List<Object>{ o.Employee__r.Name, o.Name, o.Start_Date__c, o.Days_Elapsed__c, o.Completion_Percent__c == null ? 0 : o.Completion_Percent__c.setScale(0) }));
        }
        a.text = a.rows.size() + ' onboarding process(es) have been open for more than ' + days + ' days.';
        return a;
    }

    private static Answer attritionByDepartment() {
        Map<String, Integer> exits = new Map<String, Integer>(), active = new Map<String, Integer>();
        for (AggregateResult ar : [SELECT Department__r.Name d, COUNT(Id) n FROM Employee__c WHERE Status__c IN ('Exited', 'Alumni') AND Exit_Date__c = LAST_N_DAYS:365 GROUP BY Department__r.Name]) {
            exits.put(String.valueOf(ar.get('d')), (Integer) ar.get('n'));
        }
        for (AggregateResult ar : [SELECT Department__r.Name d, COUNT(Id) n FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice') GROUP BY Department__r.Name]) {
            active.put(String.valueOf(ar.get('d')), (Integer) ar.get('n'));
        }
        Set<String> depts = new Set<String>(active.keySet());
        depts.addAll(exits.keySet());
        Answer a = table('attrition', '', new List<String>{ 'Department', 'Exits (12 mo)', 'Current headcount', 'Attrition %' });
        String top; Decimal topRate = -1;
        for (String d : depts) {
            Integer x = exits.containsKey(d) ? exits.get(d) : 0;
            Integer h = active.containsKey(d) ? active.get(d) : 0;
            Decimal rate = (h + x) == 0 ? 0 : (x * 100.0 / (h + x / 2.0)).setScale(1);
            if (rate > topRate) { topRate = rate; top = d; }
            a.rows.add(row(null, new List<Object>{ d == 'null' ? 'Unassigned' : d, x, h, rate }));
        }
        a.text = top == null ? 'No attrition data yet.' : (top == 'null' ? 'Unassigned' : top) + ' has the highest attrition at ' + topRate + '% over the last 12 months.';
        return a;
    }

    private static Answer onLeaveToday() {
        Answer a = table('on_leave_today', '', new List<String>{ 'Employee', 'Leave type', 'From', 'To' });
        for (Leave_Request__c l : [SELECT Employee__c, Employee__r.Name, Leave_Type__c, Start_Date__c, End_Date__c FROM Leave_Request__c
                                   WHERE Status__c = 'Approved' AND Start_Date__c <= TODAY AND End_Date__c >= TODAY ORDER BY Employee__r.Name LIMIT 200]) {
            a.rows.add(row(l.Employee__c, new List<Object>{ l.Employee__r.Name, l.Leave_Type__c, l.Start_Date__c, l.End_Date__c }));
        }
        a.text = a.rows.size() + ' employee(s) are on approved leave or WFH today.';
        return a;
    }

    private static Answer openTickets(String q) {
        Boolean onlyBreached = q.contains('sla') || q.contains('breach');
        Answer a = table('open_tickets', '', new List<String>{ 'Ticket', 'Subject', 'Category', 'Priority', 'Status', 'SLA due' });
        Datetime nowTs = System.now();
        String soql = 'SELECT Id, Name, Subject__c, Category__c, Priority__c, Status__c, SLA_Due__c FROM HR_Ticket__c WHERE Status__c NOT IN (\'Resolved\', \'Closed\')' +
                      (onlyBreached ? ' AND SLA_Due__c < :nowTs' : '') + ' ORDER BY SLA_Due__c LIMIT 200';
        for (HR_Ticket__c t : Database.query(soql)) {
            a.rows.add(row(t.Id, new List<Object>{ t.Name, t.Subject__c, t.Category__c, t.Priority__c, t.Status__c, t.SLA_Due__c }));
        }
        a.text = a.rows.size() + (onlyBreached ? ' open ticket(s) have breached SLA.' : ' HR ticket(s) are open.');
        return a;
    }

    private static Answer headcount() {
        Answer a = table('headcount', '', new List<String>{ 'Department', 'Active employees' });
        Integer total = 0;
        for (AggregateResult ar : [SELECT Department__r.Name d, COUNT(Id) n FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice')
                                   GROUP BY Department__r.Name ORDER BY COUNT(Id) DESC]) {
            total += (Integer) ar.get('n');
            a.rows.add(row(null, new List<Object>{ ar.get('d') == null ? 'Unassigned' : ar.get('d'), ar.get('n') }));
        }
        a.text = 'Active headcount is ' + total + ' across ' + a.rows.size() + ' department(s).';
        return a;
    }

    private static Answer birthdays() {
        Answer a = table('birthdays', '', new List<String>{ 'Employee', 'Birthday', 'Department' });
        for (Employee__c e : [SELECT Id, Name, Date_of_Birth__c, Department__r.Name FROM Employee__c
                              WHERE CALENDAR_MONTH(Date_of_Birth__c) = :Date.today().month() AND Status__c IN :PS_Util.ACTIVE_STATUSES
                              ORDER BY Date_of_Birth__c LIMIT 200]) {
            a.rows.add(row(e.Id, new List<Object>{ e.Name, e.Date_of_Birth__c.day() + ' ' + Datetime.newInstance(e.Date_of_Birth__c, Time.newInstance(0, 0, 0, 0)).format('MMMM'), e.Department__r?.Name }));
        }
        a.text = a.rows.size() + ' birthday(s) this month.';
        return a;
    }

    private static Answer newJoiners() {
        Answer a = table('new_joiners', '', new List<String>{ 'Employee', 'Joined', 'Department', 'Designation', 'Status' });
        for (Employee__c e : [SELECT Id, Name, Date_of_Joining__c, Department__r.Name, Designation__r.Name, Status__c FROM Employee__c
                              WHERE Date_of_Joining__c = THIS_MONTH ORDER BY Date_of_Joining__c LIMIT 200]) {
            a.rows.add(row(e.Id, new List<Object>{ e.Name, e.Date_of_Joining__c, e.Department__r?.Name, e.Designation__r?.Name, e.Status__c }));
        }
        a.text = a.rows.size() + ' employee(s) join this month.';
        return a;
    }

    private static Answer riskList() {
        Answer a = table('risk', '', new List<String>{ 'Employee', 'Department', 'Risk', 'Rating' });
        if (!PS_Util.canSee(Schema.SObjectType.Employee__c.fields.Attrition_Risk__c)) {
            a.mode = 'text';
            a.text = 'Attrition risk is visible to HR only.';
            return a;
        }
        for (Employee__c e : [SELECT Id, Name, Department__r.Name, Attrition_Risk__c, Performance_Rating__c FROM Employee__c
                              WHERE Attrition_Risk__c IN ('High', 'Medium') AND Status__c IN ('Active', 'Onboarding') ORDER BY Attrition_Risk__c, Name LIMIT 200]) {
            a.rows.add(row(e.Id, new List<Object>{ e.Name, e.Department__r?.Name, e.Attrition_Risk__c, e.Performance_Rating__c }));
        }
        a.text = a.rows.size() + ' employee(s) show medium or high attrition-risk indicators. These are transparent heuristics to prompt a conversation, not a prediction.';
        return a;
    }

    private static Answer assetsInStock() {
        Answer a = table('assets', '', new List<String>{ 'Asset', 'Tag', 'Type', 'Condition', 'Location' });
        for (Company_Asset__c x : [SELECT Id, Name, Asset_Tag__c, Asset_Type__c, Condition__c, Location__r.Name FROM Company_Asset__c
                                   WHERE Status__c = 'In Stock' ORDER BY Asset_Type__c LIMIT 200]) {
            a.rows.add(row(x.Id, new List<Object>{ x.Name, x.Asset_Tag__c, x.Asset_Type__c, x.Condition__c, x.Location__r?.Name }));
        }
        a.text = a.rows.size() + ' asset(s) are in stock and ready to allocate.';
        return a;
    }

    private static Answer openPositions() {
        Answer a = table('open_positions', '', new List<String>{ 'Role', 'Department', 'Location', 'Open seats', 'Days open', 'Internal' });
        for (Job_Requisition__c r : [SELECT Id, Name, Department__r.Name, Location__r.Name, Openings__c, Filled__c, Days_Open__c, Internal_Posting__c
                                     FROM Job_Requisition__c WHERE Status__c = 'Open' ORDER BY Days_Open__c DESC LIMIT 200]) {
            a.rows.add(row(r.Id, new List<Object>{ r.Name, r.Department__r?.Name, r.Location__r?.Name,
                (r.Openings__c == null ? 0 : r.Openings__c) - (r.Filled__c == null ? 0 : r.Filled__c), r.Days_Open__c, r.Internal_Posting__c ? 'Yes' : 'No' }));
        }
        a.text = a.rows.size() + ' requisition(s) are open.';
        return a;
    }

    private static Answer skillSearch(String original) {
        String cleaned = original.toLowerCase().replaceAll('\\b(who|has|have|knows|know|skills?|in|with|experience|expert|employees?|show|list|find|the|for|required|new|project|are|is|which|of|any|someone)\\b', ' ').replaceAll('[?.,!]', ' ').normalizeSpace();
        Answer a = table('skill_search', '', new List<String>{ 'Employee', 'Designation', 'Department', 'Skills' });
        if (String.isBlank(cleaned)) { a.mode = 'text'; a.text = 'Tell me which skill to look for, e.g. "Who has Python skills?"'; return a; }
        String term = PS_TicketService.searchTerm(cleaned);
        if (term == null) term = cleaned;
        List<List<SObject>> res = Search.query('FIND \'' + String.escapeSingleQuotes(term) + '\' IN ALL FIELDS RETURNING Employee__c(Id, Name, Designation__r.Name, Department__r.Name, Skills__c WHERE Status__c IN (\'Active\', \'Onboarding\', \'On Notice\')) LIMIT 50');
        for (SObject s : res[0]) {
            Employee__c e = (Employee__c) s;
            a.rows.add(row(e.Id, new List<Object>{ e.Name, e.Designation__r?.Name, e.Department__r?.Name, e.Skills__c == null ? '' : e.Skills__c.abbreviate(120) }));
        }
        a.text = a.rows.size() + ' employee(s) match "' + cleaned + '".';
        return a;
    }

    private static Answer help() {
        Answer a = new Answer();
        a.intent = 'help';
        a.text = 'I can answer workforce questions (headcount, attrition, overdue reviews or training, expiring certifications, ' +
                 'onboarding delays, who is on leave, skills search, open positions, SLA breaches) and HR policy questions grounded ' +
                 'in your company policies. If I cannot help, I can raise a ticket with HR for you.';
        return a;
    }

    // ---------------- policy copilot -------------------------------------
    @TestVisible
    private static Answer policyAnswer(String question) {
        Answer a = new Answer();
        a.intent = 'policy';
        List<HR_Policy__c> policies = PS_TicketService.suggestPolicies(question, 3);
        for (HR_Policy__c p : policies) a.sources.add(new Map<String, String>{ 'id' => p.Id, 'name' => p.Name, 'category' => p.Category__c });

        if (claudeAvailable()) {
            String reply = askClaude(question, policies);
            if (reply != null) {
                a.text = reply;
                a.usedClaude = true;
                return a;
            }
        }
        if (policies.isEmpty()) {
            a.text = 'I could not find a policy that answers this. Would you like me to raise a ticket with HR?';
            return a;
        }
        List<String> parts = new List<String>();
        for (HR_Policy__c p : policies) parts.add(p.Name + ' (v' + (p.Version__c == null ? '1' : p.Version__c) + '): ' + excerpt(p, question));
        a.text = 'Here is what our policies say:\n\n' + String.join(parts, '\n\n');
        return a;
    }

    /** Picks the sentences of a policy that share the most words with the question. */
    @TestVisible
    private static String excerpt(HR_Policy__c p, String question) {
        String body = String.isBlank(p.Policy_Body__c) ? p.Summary__c : p.Policy_Body__c;
        if (String.isBlank(body)) return '';
        Set<String> words = new Set<String>();
        String term = PS_TicketService.searchTerm(question);
        if (term != null) words.addAll(term.split(' OR '));
        List<String> sentences = body.normalizeSpace().split('(?<=[.!?])\\s+');
        List<String> picked = new List<String>();
        for (String s : sentences) {
            String low = s.toLowerCase();
            for (String w : words) if (low.contains(w)) { picked.add(s); break; }
            if (picked.size() == 3) break;
        }
        if (picked.isEmpty()) return (p.Summary__c != null ? p.Summary__c : body).abbreviate(400);
        return String.join(picked, ' ').abbreviate(700);
    }

    private static Boolean claudeAvailable() {
        if (Test.isRunningTest()) return forceClaude;
        return [SELECT COUNT() FROM NamedCredential WHERE DeveloperName = 'Claude_API'] > 0;
    }

    /**
     * Calls the Claude Messages API through the Claude_API Named Credential
     * (the API key lives in its External Credential, never in code).
     * Returns null on any failure so the assistant falls back to excerpts.
     */
    @TestVisible
    private static String askClaude(String question, List<HR_Policy__c> policies) {
        try {
            Employee__c me = PS_Util.currentEmployee();
            String context = '';
            for (HR_Policy__c p : policies) {
                context += '<policy title="' + p.Name.escapeXml() + '" version="' + (p.Version__c == null ? '1' : p.Version__c) + '">\n' +
                           (String.isBlank(p.Policy_Body__c) ? p.Summary__c : p.Policy_Body__c).abbreviate(12000) + '\n</policy>\n';
            }
            String sysPrompt = 'You are PeopleSphere, the HR assistant for ' +
                (me != null && me.Organization__c != null ? 'this company' : 'the company') + '. ' +
                'Answer employee questions using ONLY the company policies provided. Quote policy names you rely on. ' +
                'If the policies do not answer the question, say so plainly and suggest raising an HR ticket. ' +
                'Keep answers under 180 words, friendly and specific. Never make or promise decisions about hiring, ' +
                'termination, promotion or pay.';
            Map<String, Object> body = new Map<String, Object>{
                'model' => CLAUDE_MODEL,
                'max_tokens' => 4000,
                'output_config' => new Map<String, Object>{ 'effort' => 'low' },
                'fallbacks' => 'default',
                'system' => sysPrompt,
                'messages' => new List<Object>{
                    new Map<String, Object>{ 'role' => 'user', 'content' =>
                        (context == '' ? 'No matching policies were found.\n\n' : '<policies>\n' + context + '</policies>\n\n') +
                        'Employee question: ' + question }
                }
            };
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Claude_API/v1/messages');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('anthropic-version', '2026-10-21');
            req.setHeader('anthropic-beta', 'server-side-fallback-2026-07-01');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(body));
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.WARN, 'Claude API ' + res.getStatusCode() + ': ' + res.getBody());
                return null;
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (parsed.get('stop_reason') == 'refusal') return null;
            List<String> texts = new List<String>();
            for (Object block : (List<Object>) parsed.get('content')) {
                Map<String, Object> b = (Map<String, Object>) block;
                if (b.get('type') == 'text') texts.add((String) b.get('text'));
            }
            return texts.isEmpty() ? null : String.join(texts, '\n').trim();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Claude call failed: ' + e.getMessage());
            return null;
        }
    }

    // ---------------- helpers ---------------------------------------------
    private static Map<String, Object> row(Id recordId, List<Object> values) {
        Map<String, Object> r = new Map<String, Object>{ 'id' => recordId };
        for (Integer i = 0; i < values.size(); i++) r.put('c' + i, values[i] instanceof Date ? (Object) ((Date) values[i]).format() : values[i]);
        return r;
    }

    private static Integer firstNumber(String q, Integer fallback) {
        Matcher m = Pattern.compile('(\\d+)').matcher(q);
        return m.find() ? Integer.valueOf(m.group(1)) : fallback;
    }
}
