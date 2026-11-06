/**
 * HR service desk: AI-style ticket classification (transparent keyword
 * scoring), priority detection, SLA calculation from SLA_Policy__mdt,
 * least-loaded routing, policy suggestions and SLA escalation.
 */
public without sharing class PS_TicketService {

    @TestVisible
    private static final Map<String, List<String>> CATEGORY_KEYWORDS = new Map<String, List<String>>{
        'Payroll' => new List<String>{ 'salary', 'payslip', 'pay slip', 'payroll', 'deduction', 'tax', 'tds', 'form 16', 'arrears', 'credited', 'ctc', 'bonus' },
        'Leave & Attendance' => new List<String>{ 'leave', 'attendance', 'holiday', 'check-in', 'check in', 'wfh', 'work from home', 'absent', 'shift', 'overtime', 'late' },
        'Benefits & Insurance' => new List<String>{ 'insurance', 'medical', 'health', 'benefit', 'claim', 'hospital', 'reimburse', 'pf', 'provident', 'gratuity' },
        'Policy Question' => new List<String>{ 'policy', 'rule', 'allowed', 'guideline', 'eligible', 'eligibility', 'handbook', 'dress code' },
        'IT Access' => new List<String>{ 'password', 'access', 'login', 'vpn', 'laptop', 'email account', 'sso', 'software', 'license', 'locked' },
        'Documents & Letters' => new List<String>{ 'letter', 'certificate', 'document', 'proof', 'verification', 'address proof', 'employment letter', 'noc' },
        'Onboarding' => new List<String>{ 'joining', 'onboarding', 'new joiner', 'induction', 'first day', 'offer letter' },
        'Exit & Settlement' => new List<String>{ 'resign', 'resignation', 'exit', 'relieving', 'settlement', 'notice period', 'full and final', 'last working' },
        'Grievance' => new List<String>{ 'harass', 'complaint', 'grievance', 'discriminat', 'unfair', 'bully', 'abuse', 'misconduct', 'unsafe' },
        'Learning' => new List<String>{ 'training', 'course', 'certification', 'learning', 'quiz', 'exam' }
    };
    private static final List<String> CRITICAL_WORDS = new List<String>{ 'harass', 'unsafe', 'abuse', 'threat', 'emergency', 'discriminat' };
    private static final List<String> HIGH_WORDS = new List<String>{ 'urgent', 'asap', 'immediately', 'not credited', 'blocked', 'cannot work', 'locked out' };

    public class Classification {
        @AuraEnabled public String category;
        @AuraEnabled public Integer confidence;
        @AuraEnabled public String priority;
    }

    public static Classification classify(String text) {
        Classification c = new Classification();
        c.category = 'Other';
        c.confidence = 0;
        c.priority = null;
        if (String.isBlank(text)) return c;
        String t = text.toLowerCase();
        Integer best = 0, total = 0;
        for (String cat : CATEGORY_KEYWORDS.keySet()) {
            Integer score = 0;
            for (String k : CATEGORY_KEYWORDS.get(cat)) if (t.contains(k)) score++;
            total += score;
            if (score > best) { best = score; c.category = cat; }
        }
        if (best > 0) c.confidence = Math.min(95, (Integer) Math.round(40 + 55.0 * best / Math.max(total, 1)));
        for (String w : CRITICAL_WORDS) if (t.contains(w)) c.priority = 'Critical';
        if (c.priority == null) for (String w : HIGH_WORDS) if (t.contains(w)) c.priority = 'High';
        return c;
    }

    public static Map<String, Decimal> slaHours() {
        Map<String, Decimal> out = new Map<String, Decimal>{ 'Critical' => 4, 'High' => 8, 'Medium' => 24, 'Low' => 72 };
        for (SLA_Policy__mdt p : SLA_Policy__mdt.getAll().values()) {
            if (p.Resolution_Hours__c != null) out.put(p.MasterLabel, p.Resolution_Hours__c);
        }
        return out;
    }

    public static void beforeInsert(List<HR_Ticket__c> rows) {
        Employee__c me = PS_Util.currentEmployee();
        Map<String, Decimal> sla = slaHours();
        List<Id> agents = PS_Util.hrUserIds();
        Map<Id, Integer> load = new Map<Id, Integer>();
        for (Id a : agents) load.put(a, 0);
        if (!agents.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Assigned_To__c u, COUNT(Id) n FROM HR_Ticket__c
                WHERE Assigned_To__c IN :agents AND Status__c NOT IN ('Resolved', 'Closed') GROUP BY Assigned_To__c
            ]) {
                load.put((Id) ar.get('u'), (Integer) ar.get('n'));
            }
        }
        for (HR_Ticket__c t : rows) {
            if (t.Employee__c == null && me != null) t.Employee__c = me.Id;
            if (String.isBlank(t.Subject__c) && String.isNotBlank(t.Description__c)) t.Subject__c = t.Description__c.abbreviate(80);
            Classification c = classify((t.Subject__c == null ? '' : t.Subject__c) + ' ' + (t.Description__c == null ? '' : t.Description__c));
            t.AI_Suggested_Category__c = c.category;
            t.AI_Confidence__c = c.confidence;
            if (t.Category__c == null || t.Category__c == 'Other') t.Category__c = c.category;
            if (c.priority != null && rank(c.priority) > rank(t.Priority__c)) t.Priority__c = c.priority;
            if (t.Category__c == 'Grievance') {
                t.Confidential__c = true;
                if (rank(t.Priority__c) < rank('High')) t.Priority__c = 'High';
            }
            if (t.Priority__c == null) t.Priority__c = 'Medium';
            if (t.Status__c == null) t.Status__c = 'New';
            t.SLA_Due__c = System.now().addMinutes((Integer) (sla.get(t.Priority__c) * 60));
            if (t.Assigned_To__c == null) {
                Id pick = null;
                for (Id a : load.keySet()) if (pick == null || load.get(a) < load.get(pick)) pick = a;
                t.Assigned_To__c = pick != null ? pick : UserInfo.getUserId();
                if (pick != null) load.put(pick, load.get(pick) + 1);
            }
            if (t.Related_Policy__c == null) {
                List<HR_Policy__c> pol = suggestPolicies(t.Subject__c + ' ' + t.Description__c, 1);
                if (!pol.isEmpty()) t.Related_Policy__c = pol[0].Id;
            }
        }
    }

    public static void beforeUpdate(List<HR_Ticket__c> rows, Map<Id, HR_Ticket__c> oldMap) {
        Map<String, Decimal> sla = slaHours();
        for (HR_Ticket__c t : rows) {
            HR_Ticket__c o = oldMap.get(t.Id);
            if (t.Status__c != o.Status__c) {
                if ((t.Status__c == 'Resolved' || t.Status__c == 'Closed') && t.Resolved_On__c == null) t.Resolved_On__c = System.now();
                if (t.Status__c != 'Resolved' && t.Status__c != 'Closed') t.Resolved_On__c = null;
                if (o.Status__c == 'New' && t.First_Response_At__c == null) t.First_Response_At__c = System.now();
            }
            if (t.Priority__c != o.Priority__c && t.Resolved_On__c == null) {
                t.SLA_Due__c = t.CreatedDate.addMinutes((Integer) (sla.get(t.Priority__c) * 60));
            }
            if (t.Status__c == 'Resolved' && String.isBlank(t.Resolution__c)) t.Resolution__c.addError('Add a resolution before resolving the ticket.');
        }
    }

    public static void afterSave(List<HR_Ticket__c> rows, Map<Id, HR_Ticket__c> oldMap) {
        Set<Id> empIds = new Set<Id>();
        for (HR_Ticket__c t : rows) empIds.add(t.Employee__c);
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([SELECT Id, User__c FROM Employee__c WHERE Id IN :empIds]);
        for (HR_Ticket__c t : rows) {
            HR_Ticket__c o = oldMap == null ? null : oldMap.get(t.Id);
            if (o == null || o.Assigned_To__c != t.Assigned_To__c) {
                if (t.Assigned_To__c != UserInfo.getUserId()) {
                    PS_Util.notify(t.Assigned_To__c, 'HR ticket assigned (' + t.Priority__c + ')', t.Subject__c, t.Id);
                }
            }
            if (o != null && o.Status__c != t.Status__c && t.Status__c == 'Resolved' && emps.get(t.Employee__c)?.User__c != null) {
                PS_Util.notify(emps.get(t.Employee__c).User__c, 'Your HR ticket was resolved', t.Subject__c, t.Id);
            }
        }
    }

    /** Escalates open tickets that breached SLA. Called by the daily job and on demand. */
    public static Integer escalateBreached() {
        List<HR_Ticket__c> breached = [
            SELECT Id, Subject__c, Assigned_To__c, Escalation_Level__c, Priority__c FROM HR_Ticket__c
            WHERE Status__c NOT IN ('Resolved', 'Closed', 'Escalated') AND SLA_Due__c < :System.now() LIMIT 500
        ];
        Map<Id, Id> managerOf = new Map<Id, Id>();
        Set<Id> assignees = new Set<Id>();
        for (HR_Ticket__c t : breached) assignees.add(t.Assigned_To__c);
        for (User u : [SELECT Id, ManagerId FROM User WHERE Id IN :assignees]) managerOf.put(u.Id, u.ManagerId);
        for (HR_Ticket__c t : breached) {
            t.Status__c = 'Escalated';
            t.Escalated__c = true;
            t.Escalation_Level__c = (t.Escalation_Level__c == null ? 0 : t.Escalation_Level__c) + 1;
            if (t.Priority__c != 'Critical') t.Priority__c = t.Priority__c == 'High' ? 'Critical' : 'High';
            PS_Util.notify(new Set<Id>{ t.Assigned_To__c, managerOf.get(t.Assigned_To__c) }, 'SLA breached - ticket escalated', t.Subject__c, t.Id);
        }
        if (!breached.isEmpty()) update breached;
        return breached.size();
    }

    /** Finds active policies relevant to free text using SOSL across title, summary, keywords and body. */
    public static List<HR_Policy__c> suggestPolicies(String text, Integer max) {
        List<HR_Policy__c> out = new List<HR_Policy__c>();
        String term = searchTerm(text);
        if (term == null) return out;
        List<List<SObject>> res = Search.query('FIND \'' + String.escapeSingleQuotes(term) + '\' IN ALL FIELDS RETURNING HR_Policy__c(Id, Name, Category__c, Summary__c, Policy_Body__c, Version__c WHERE Active__c = true) LIMIT ' + max);
        for (SObject s : res[0]) out.add((HR_Policy__c) s);
        return out;
    }

    private static final Set<String> STOP_WORDS = new Set<String>{
        'the', 'and', 'for', 'with', 'what', 'when', 'where', 'which', 'who', 'how', 'can', 'are', 'our', 'your', 'you', 'have',
        'has', 'does', 'did', 'this', 'that', 'there', 'from', 'about', 'into', 'show', 'tell', 'please', 'need', 'want', 'get',
        'many', 'much', 'any', 'all', 'is', 'my', 'me', 'i', 'a', 'an', 'to', 'of', 'in', 'on', 'it', 'do', 'be', 'am', 'or', 'not', 'null'
    };

    /** Builds an OR search term from the meaningful words of a sentence. */
    public static String searchTerm(String text) {
        if (String.isBlank(text)) return null;
        List<String> words = new List<String>();
        for (String w : text.toLowerCase().replaceAll('[^a-z0-9 ]', ' ').split(' ')) {
            if (w.length() > 2 && !STOP_WORDS.contains(w) && !words.contains(w)) words.add(w);
            if (words.size() == 6) break;
        }
        return words.isEmpty() ? null : String.join(words, ' OR ');
    }

    private static Integer rank(String p) {
        return p == 'Critical' ? 4 : p == 'High' ? 3 : p == 'Medium' ? 2 : p == 'Low' ? 1 : 0;
    }
}
