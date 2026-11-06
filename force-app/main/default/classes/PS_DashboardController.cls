/**
 * Organization overview for HR and leadership: workforce, lifecycle, learning,
 * service desk, recruitment, engagement and risk analytics in one call.
 */
public inherited sharing class PS_DashboardController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getOverview() {
        try {
            Map<String, Object> out = new Map<String, Object>();
            Date today = Date.today();

            // ---- Workforce -------------------------------------------------
            Integer active = [SELECT COUNT() FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice')];
            Integer preboarding = [SELECT COUNT() FROM Employee__c WHERE Status__c = 'Pre-boarding'];
            Integer onNotice = [SELECT COUNT() FROM Employee__c WHERE Status__c = 'On Notice'];
            Integer joiners30 = [SELECT COUNT() FROM Employee__c WHERE Date_of_Joining__c = LAST_N_DAYS:30];
            Integer exits12m = [SELECT COUNT() FROM Employee__c WHERE Exit_Date__c = LAST_N_DAYS:365 AND Status__c IN ('Exited', 'Alumni')];
            Decimal avgHeadcount = (active + exits12m / 2.0);
            Decimal attrition = avgHeadcount == 0 ? 0 : (exits12m * 100.0 / avgHeadcount).setScale(1);

            out.put('headcountByDepartment', group([SELECT Department__r.Name k, COUNT(Id) v FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice') GROUP BY Department__r.Name ORDER BY COUNT(Id) DESC LIMIT 12]));
            out.put('headcountByLocation', group([SELECT Location__r.Name k, COUNT(Id) v FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice') GROUP BY Location__r.Name ORDER BY COUNT(Id) DESC LIMIT 10]));
            out.put('headcountByType', group([SELECT Employment_Type__c k, COUNT(Id) v FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice') GROUP BY Employment_Type__c]));
            out.put('statusDistribution', group([SELECT Status__c k, COUNT(Id) v FROM Employee__c GROUP BY Status__c]));
            out.put('attritionRisk', group([SELECT Attrition_Risk__c k, COUNT(Id) v FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding') AND Attrition_Risk__c != null GROUP BY Attrition_Risk__c]));
            out.put('exitReasons', group([SELECT Exit_Reason__c k, COUNT(Id) v FROM Exit_Process__c WHERE Exit_Reason__c != null AND CreatedDate = LAST_N_DAYS:365 GROUP BY Exit_Reason__c ORDER BY COUNT(Id) DESC LIMIT 8]));

            // monthly joiners vs exits (last 6 months)
            List<Map<String, Object>> trend = new List<Map<String, Object>>();
            Date firstMonth = today.toStartOfMonth().addMonths(-5);
            Map<String, Integer> j = new Map<String, Integer>(), x = new Map<String, Integer>();
            for (Employee__c e : [SELECT Date_of_Joining__c, Exit_Date__c FROM Employee__c WHERE Date_of_Joining__c >= :firstMonth OR Exit_Date__c >= :firstMonth LIMIT 10000]) {
                if (e.Date_of_Joining__c != null && e.Date_of_Joining__c >= firstMonth) inc(j, monthKey(e.Date_of_Joining__c));
                if (e.Exit_Date__c != null && e.Exit_Date__c >= firstMonth && e.Exit_Date__c <= today) inc(x, monthKey(e.Exit_Date__c));
            }
            for (Integer i = 0; i < 6; i++) {
                Date m = firstMonth.addMonths(i);
                String k = monthKey(m);
                trend.add(new Map<String, Object>{ 'label' => Datetime.newInstance(m, Time.newInstance(0, 0, 0, 0)).format('MMM'),
                    'joiners' => j.containsKey(k) ? j.get(k) : 0, 'exits' => x.containsKey(k) ? x.get(k) : 0 });
            }
            out.put('hiringTrend', trend);

            // ---- Onboarding -----------------------------------------------
            List<Map<String, Object>> onbRows = new List<Map<String, Object>>();
            Decimal pctSum = 0;
            Integer delayed = 0;
            List<Onboarding__c> openOnb = [
                SELECT Id, Name, Employee__r.Name, Employee__r.Department__r.Name, Completion_Percent__c, Start_Date__c, Target_Completion_Date__c, Days_Elapsed__c
                FROM Onboarding__c WHERE Status__c IN ('Not Started', 'In Progress') ORDER BY Start_Date__c DESC LIMIT 200];
            for (Onboarding__c o : openOnb) {
                pctSum += o.Completion_Percent__c == null ? 0 : o.Completion_Percent__c;
                Boolean late = o.Target_Completion_Date__c != null && o.Target_Completion_Date__c < today;
                if (late) delayed++;
                if (onbRows.size() < 8) {
                    onbRows.add(new Map<String, Object>{ 'id' => o.Id, 'employee' => o.Employee__r.Name, 'department' => o.Employee__r.Department__r?.Name,
                        'percent' => o.Completion_Percent__c == null ? 0 : o.Completion_Percent__c.setScale(0), 'days' => o.Days_Elapsed__c, 'late' => late });
                }
            }
            out.put('onboardingPipeline', onbRows);

            // ---- Learning ---------------------------------------------------
            Integer mandatoryTotal = [SELECT COUNT() FROM Learning_Enrollment__c WHERE Course__r.Mandatory__c = true AND Status__c != 'Waived'];
            Integer mandatoryDone = [SELECT COUNT() FROM Learning_Enrollment__c WHERE Course__r.Mandatory__c = true AND Status__c = 'Completed'];
            Integer overdueTraining = [SELECT COUNT() FROM Learning_Enrollment__c WHERE Status__c = 'Overdue' OR (Status__c IN ('Assigned', 'In Progress') AND Due_Date__c < TODAY)];
            List<Map<String, Object>> learnByCat = new List<Map<String, Object>>();
            Map<String, Integer[]> cat = new Map<String, Integer[]>();
            for (AggregateResult ar : [SELECT Course__r.Category__c c, Status__c s, COUNT(Id) n FROM Learning_Enrollment__c WHERE Status__c != 'Waived' GROUP BY Course__r.Category__c, Status__c]) {
                String c = (String) ar.get('c') == null ? 'Other' : (String) ar.get('c');
                if (!cat.containsKey(c)) cat.put(c, new Integer[]{ 0, 0 });
                cat.get(c)[1] += (Integer) ar.get('n');
                if (ar.get('s') == 'Completed') cat.get(c)[0] += (Integer) ar.get('n');
            }
            for (String c : cat.keySet()) {
                Integer[] v = cat.get(c);
                learnByCat.add(new Map<String, Object>{ 'label' => c, 'value' => v[1] == 0 ? 0 : Math.round(v[0] * 100.0 / v[1]), 'total' => v[1] });
            }
            out.put('learningByCategory', learnByCat);

            // ---- Performance -----------------------------------------------
            String yr = String.valueOf(today.year());
            Map<String, Integer> buckets = new Map<String, Integer>{ '1 - Needs improvement' => 0, '2 - Developing' => 0, '3 - Meets' => 0, '4 - Exceeds' => 0, '5 - Outstanding' => 0 };
            List<String> bucketKeys = new List<String>(buckets.keySet());
            for (Performance_Review__c r : [SELECT Final_Rating__c FROM Performance_Review__c WHERE Status__c = 'Completed' AND Final_Rating__c != null AND (Review_Year__c = :yr OR Completed_On__c = LAST_N_DAYS:365) LIMIT 10000]) {
                Integer b = Math.max(1, Math.min(5, (Integer) Math.round(r.Final_Rating__c)));
                inc(buckets, bucketKeys[b - 1]);
            }
            List<Map<String, Object>> perf = new List<Map<String, Object>>();
            for (String k : bucketKeys) perf.add(new Map<String, Object>{ 'label' => k, 'value' => buckets.get(k) });
            out.put('performanceDistribution', perf);
            Integer overdueReviews = [SELECT COUNT() FROM Performance_Review__c WHERE Is_Overdue__c = true];

            // ---- Service desk ----------------------------------------------
            Integer openTickets = [SELECT COUNT() FROM HR_Ticket__c WHERE Status__c NOT IN ('Resolved', 'Closed')];
            Integer breached = [SELECT COUNT() FROM HR_Ticket__c WHERE Status__c NOT IN ('Resolved', 'Closed') AND SLA_Due__c < :System.now()];
            out.put('ticketsByCategory', group([SELECT Category__c k, COUNT(Id) v FROM HR_Ticket__c WHERE CreatedDate = LAST_N_DAYS:90 GROUP BY Category__c ORDER BY COUNT(Id) DESC LIMIT 10]));
            Decimal csatSum = 0; Integer csatN = 0;
            for (HR_Ticket__c t : [SELECT Satisfaction_Rating__c FROM HR_Ticket__c WHERE Satisfaction_Rating__c != null AND CreatedDate = LAST_N_DAYS:180 LIMIT 5000]) {
                csatSum += Decimal.valueOf(t.Satisfaction_Rating__c); csatN++;
            }

            // ---- Recruitment -----------------------------------------------
            out.put('pipelineByStage', orderedGroup([SELECT Stage__c k, COUNT(Id) v FROM Candidate__c WHERE Stage__c NOT IN ('Rejected', 'Withdrawn') GROUP BY Stage__c],
                new List<String>{ 'Applied', 'Screening', 'Interview', 'Offer', 'Offer Accepted', 'Hired' }));
            Decimal openPositions = 0;
            Integer openReqs = 0;
            for (Job_Requisition__c r : [SELECT Openings__c, Filled__c FROM Job_Requisition__c WHERE Status__c = 'Open']) {
                openReqs++;
                openPositions += (r.Openings__c == null ? 0 : r.Openings__c) - (r.Filled__c == null ? 0 : r.Filled__c);
            }

            // ---- Engagement (eNPS = % promoters - % detractors) -----------
            Integer promoters = 0, detractors = 0, responses = 0;
            for (Survey_Response__c r : [SELECT Score__c FROM Survey_Response__c WHERE Pulse_Survey__r.Survey_Type__c = 'eNPS' AND CreatedDate = LAST_N_DAYS:180 LIMIT 10000]) {
                responses++;
                if (r.Score__c >= 9) promoters++; else if (r.Score__c <= 6) detractors++;
            }
            Integer enps = responses == 0 ? null : (Integer) Math.round((promoters - detractors) * 100.0 / responses);

            // ---- Leave today -----------------------------------------------
            Integer onLeaveToday = [SELECT COUNT() FROM Leave_Request__c WHERE Status__c = 'Approved' AND Start_Date__c <= TODAY AND End_Date__c >= TODAY AND Leave_Type__c != 'Work From Home'];
            Integer pendingLeave = [SELECT COUNT() FROM Leave_Request__c WHERE Status__c = 'Submitted'];

            // ---- Workforce cost (only for users who can see compensation) ---
            if (PS_Util.canSee(Schema.SObjectType.Employee__c.fields.Annual_CTC__c)) {
                out.put('costByDepartment', group([SELECT Department__r.Name k, SUM(Annual_CTC__c) v FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding', 'On Notice') AND Annual_CTC__c != null GROUP BY Department__r.Name ORDER BY SUM(Annual_CTC__c) DESC LIMIT 10]));
            }

            out.put('kpis', new Map<String, Object>{
                'activeHeadcount' => active, 'preboarding' => preboarding, 'onNotice' => onNotice, 'joiners30' => joiners30,
                'exits12m' => exits12m, 'attritionRate' => attrition,
                'openOnboarding' => openOnb.size(), 'avgOnboardingCompletion' => openOnb.isEmpty() ? 0 : (pctSum / openOnb.size()).setScale(0),
                'delayedOnboarding' => delayed,
                'trainingCompliance' => mandatoryTotal == 0 ? 100 : Math.round(mandatoryDone * 100.0 / mandatoryTotal),
                'overdueTraining' => overdueTraining, 'overdueReviews' => overdueReviews,
                'openTickets' => openTickets, 'slaBreached' => breached, 'csat' => csatN == 0 ? null : (csatSum / csatN).setScale(1),
                'openRequisitions' => openReqs, 'openPositions' => openPositions,
                'enps' => enps, 'surveyResponses' => responses, 'onLeaveToday' => onLeaveToday, 'pendingLeave' => pendingLeave
            });
            out.put('alerts', alerts());
            out.put('generatedAt', System.now());
            return out;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    /** Compliance control centre: the operational risks HR should act on today. */
    private static List<Map<String, Object>> alerts() {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        add(out, 'error', [SELECT COUNT() FROM HR_Ticket__c WHERE Status__c NOT IN ('Resolved', 'Closed') AND SLA_Due__c < :System.now()], 'HR tickets breached SLA', 'HR_Ticket__c');
        add(out, 'warning', [SELECT COUNT() FROM Certification__c WHERE Expires_On__c >= TODAY AND Expires_On__c = NEXT_N_DAYS:30], 'certifications expire in the next 30 days', 'Certification__c');
        add(out, 'error', [SELECT COUNT() FROM Certification__c WHERE Expires_On__c < TODAY AND Employee__r.Status__c IN ('Active', 'On Notice')], 'active employees hold expired certifications', 'Certification__c');
        add(out, 'warning', [SELECT COUNT() FROM Employee_Document__c WHERE Mandatory__c = true AND Verification_Status__c IN ('Pending Upload', 'Rejected') AND Employee__r.Status__c IN ('Pre-boarding', 'Onboarding', 'Active')], 'mandatory documents missing or rejected', 'Employee_Document__c');
        add(out, 'warning', [SELECT COUNT() FROM Employee_Document__c WHERE Expiry_Date__c = NEXT_N_DAYS:30], 'documents expire in the next 30 days', 'Employee_Document__c');
        add(out, 'warning', [SELECT COUNT() FROM Performance_Review__c WHERE Is_Overdue__c = true], 'performance reviews are overdue', 'Performance_Review__c');
        add(out, 'warning', [SELECT COUNT() FROM Onboarding__c WHERE Status__c = 'In Progress' AND Target_Completion_Date__c < TODAY], 'onboardings are past their target date', 'Onboarding__c');
        add(out, 'info', [SELECT COUNT() FROM Exit_Process__c WHERE Status__c NOT IN ('Completed', 'Withdrawn', 'Rejected') AND Pending_Assets__c > 0], 'exiting employees still hold company assets', 'Exit_Process__c');
        add(out, 'info', [SELECT COUNT() FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding') AND Background_Check_Status__c IN ('Not Started', 'Flagged')], 'employees without a cleared background check', 'Employee__c');
        return out;
    }

    private static void add(List<Map<String, Object>> out, String level, Integer count, String text, String obj) {
        if (count > 0) out.add(new Map<String, Object>{ 'level' => level, 'count' => count, 'text' => text, 'object' => obj });
    }

    private static List<Map<String, Object>> group(List<AggregateResult> rows) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (AggregateResult ar : rows) {
            Object k = ar.get('k');
            out.add(new Map<String, Object>{ 'label' => k == null ? 'Unassigned' : String.valueOf(k), 'value' => ar.get('v') });
        }
        return out;
    }

    private static List<Map<String, Object>> orderedGroup(List<AggregateResult> rows, List<String> order) {
        Map<String, Object> byKey = new Map<String, Object>();
        for (AggregateResult ar : rows) byKey.put((String) ar.get('k'), ar.get('v'));
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (String k : order) out.add(new Map<String, Object>{ 'label' => k, 'value' => byKey.containsKey(k) ? byKey.get(k) : 0 });
        return out;
    }

    private static String monthKey(Date d) { return d.year() + '-' + d.month(); }
    private static void inc(Map<String, Integer> m, String k) { m.put(k, (m.containsKey(k) ? m.get(k) : 0) + 1); }
}
