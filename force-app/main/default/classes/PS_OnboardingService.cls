/**
 * Onboarding orchestrator. Picks the most specific active checklist template
 * for each new employee, generates tasks for HR / IT / Finance / Manager /
 * Employee / Learning teams, creates required document placeholders and
 * completes the onboarding once every mandatory task is done.
 */
public without sharing class PS_OnboardingService {

    // name, team, category, day offset, mandatory
    @TestVisible
    private static final List<List<Object>> DEFAULT_TASKS = new List<List<Object>>{
        new List<Object>{ 'Send welcome email and joining kit', 'HR', 'Orientation', -3, true },
        new List<Object>{ 'Collect signed offer letter', 'HR', 'Documentation', -2, true },
        new List<Object>{ 'Verify identity and address documents', 'HR', 'Documentation', 0, true },
        new List<Object>{ 'Initiate background verification', 'HR', 'Compliance', 0, true },
        new List<Object>{ 'Allocate laptop and accessories', 'IT', 'Equipment', -1, true },
        new List<Object>{ 'Create email, SSO and system accounts', 'IT', 'Access', -1, true },
        new List<Object>{ 'Issue access card', 'Facilities', 'Equipment', 0, true },
        new List<Object>{ 'Set up payroll and bank details', 'Finance', 'Documentation', 3, true },
        new List<Object>{ 'Enroll in insurance and benefits', 'Finance', 'Documentation', 7, false },
        new List<Object>{ 'Complete joining forms and emergency contacts', 'Employee', 'Documentation', 1, true },
        new List<Object>{ 'Acknowledge employee handbook and policies', 'Employee', 'Compliance', 2, true },
        new List<Object>{ 'Team introduction and 30-60-90 day plan', 'Manager', 'Orientation', 1, true },
        new List<Object>{ 'Assign onboarding buddy', 'Manager', 'Orientation', 0, false },
        new List<Object>{ 'Complete mandatory compliance training', 'Learning', 'Training', 14, true },
        new List<Object>{ '30-day check-in', 'Manager', 'Orientation', 30, false }
    };

    @TestVisible
    private static final List<String> REQUIRED_DOCUMENTS = new List<String>{
        'Offer Letter', 'Aadhaar Card', 'PAN Card', 'Degree Certificate', 'Bank Proof', 'Photograph'
    };

    public static void startOnboarding(Set<Id> employeeIds) {
        List<Employee__c> emps = [
            SELECT Id, Name, Organization__c, Department__c, Location__c, Employment_Type__c, Date_of_Joining__c,
                   User__c, Manager__r.User__c, Status__c,
                   (SELECT Id FROM Onboardings__r WHERE Status__c NOT IN ('Completed', 'Cancelled')),
                   (SELECT Document_Type__c FROM Documents__r)
            FROM Employee__c WHERE Id IN :employeeIds
        ];
        List<Checklist_Template__c> templates = [
            SELECT Id, Organization__c, Department__c, Location__c, Employment_Type__c, Duration_Days__c,
                   (SELECT Name, Assigned_Team__c, Category__c, Days_Offset__c, Mandatory__c, Sequence__c, Description__c
                    FROM Items__r ORDER BY Sequence__c NULLS LAST, Days_Offset__c)
            FROM Checklist_Template__c WHERE Process_Type__c = 'Onboarding' AND Active__c = true
        ];

        Map<Id, Onboarding__c> onbByEmp = new Map<Id, Onboarding__c>();
        Map<Id, Checklist_Template__c> tplByEmp = new Map<Id, Checklist_Template__c>();
        List<Employee_Document__c> docs = new List<Employee_Document__c>();
        for (Employee__c e : emps) {
            if (!e.Onboardings__r.isEmpty()) continue;
            Checklist_Template__c tpl = bestTemplate(templates, e.Organization__c, e.Department__c, e.Location__c, e.Employment_Type__c);
            Date start = e.Date_of_Joining__c != null ? e.Date_of_Joining__c : Date.today();
            Integer duration = tpl != null && tpl.Duration_Days__c != null ? tpl.Duration_Days__c.intValue() : 30;
            onbByEmp.put(e.Id, new Onboarding__c(
                Employee__c = e.Id, Status__c = 'In Progress', Start_Date__c = start,
                Target_Completion_Date__c = start.addDays(duration),
                Checklist_Template__c = tpl?.Id,
                Welcome_Message__c = 'Welcome to the team, ' + e.Name + '! Your onboarding checklist is ready.'));
            if (tpl != null) tplByEmp.put(e.Id, tpl);

            Set<String> haveDocs = new Set<String>();
            for (Employee_Document__c d : e.Documents__r) haveDocs.add(d.Document_Type__c);
            for (String docType : REQUIRED_DOCUMENTS) {
                if (!haveDocs.contains(docType)) {
                    docs.add(new Employee_Document__c(Name = docType, Employee__c = e.Id, Document_Type__c = docType,
                        Verification_Status__c = 'Pending Upload', Mandatory__c = true));
                }
            }
        }
        if (onbByEmp.isEmpty()) return;
        insert onbByEmp.values();
        if (!docs.isEmpty()) insert docs;

        List<Onboarding_Task__c> tasks = new List<Onboarding_Task__c>();
        Map<Id, Employee__c> empMap = new Map<Id, Employee__c>(emps);
        for (Id empId : onbByEmp.keySet()) {
            Onboarding__c onb = onbByEmp.get(empId);
            Employee__c e = empMap.get(empId);
            Checklist_Template__c tpl = tplByEmp.get(empId);
            Integer seq = 1;
            if (tpl != null && !tpl.Items__r.isEmpty()) {
                for (Checklist_Template_Item__c item : tpl.Items__r) {
                    tasks.add(buildTask(onb, e, item.Name, item.Assigned_Team__c, item.Category__c,
                        item.Days_Offset__c == null ? 0 : item.Days_Offset__c.intValue(), item.Mandatory__c,
                        item.Sequence__c == null ? seq : item.Sequence__c.intValue(), item.Description__c));
                    seq++;
                }
            } else {
                for (List<Object> t : DEFAULT_TASKS) {
                    tasks.add(buildTask(onb, e, (String) t[0], (String) t[1], (String) t[2], (Integer) t[3], (Boolean) t[4], seq++, null));
                }
            }
        }
        insert tasks;

        Map<Id, Set<Id>> notifyByOnb = new Map<Id, Set<Id>>();
        for (Onboarding_Task__c t : tasks) {
            if (t.Assigned_To__c == null) continue;
            if (!notifyByOnb.containsKey(t.Onboarding__c)) notifyByOnb.put(t.Onboarding__c, new Set<Id>());
            notifyByOnb.get(t.Onboarding__c).add(t.Assigned_To__c);
        }
        for (Id empId : onbByEmp.keySet()) {
            Onboarding__c onb = onbByEmp.get(empId);
            if (notifyByOnb.containsKey(onb.Id)) {
                PS_Util.notify(notifyByOnb.get(onb.Id), 'New onboarding: ' + empMap.get(empId).Name,
                    'You have onboarding tasks for ' + empMap.get(empId).Name + '.', onb.Id);
            }
        }
    }

    public static Checklist_Template__c bestTemplate(List<Checklist_Template__c> templates, Id orgId, Id deptId, Id locId, String empType) {
        Checklist_Template__c best;
        Integer bestScore = -1;
        for (Checklist_Template__c t : templates) {
            Integer score = 0;
            if (t.Organization__c != null) { if (t.Organization__c != orgId) continue; score++; }
            if (t.Department__c != null) { if (t.Department__c != deptId) continue; score += 4; }
            if (t.Location__c != null) { if (t.Location__c != locId) continue; score += 2; }
            if (t.Employment_Type__c != null) { if (t.Employment_Type__c != empType) continue; score += 2; }
            if (score > bestScore) { best = t; bestScore = score; }
        }
        return best;
    }

    private static Onboarding_Task__c buildTask(Onboarding__c onb, Employee__c e, String name, String team, String category,
                                                Integer offset, Boolean mandatory, Integer seq, String description) {
        return new Onboarding_Task__c(
            Name = name.abbreviate(80), Onboarding__c = onb.Id, Assigned_Team__c = team, Category__c = category,
            Due_Date__c = onb.Start_Date__c.addDays(offset), Mandatory__c = mandatory, Sequence__c = seq,
            Description__c = description, Status__c = 'Not Started',
            Assigned_To__c = resolveAssignee(team, e.User__c, e.Manager__r?.User__c));
    }

    public static Id resolveAssignee(String team, Id employeeUser, Id managerUser) {
        if (team == 'Employee' && employeeUser != null) return employeeUser;
        if (team == 'Manager' && managerUser != null) return managerUser;
        return UserInfo.getUserId();
    }

    // ---- task trigger hooks ---------------------------------------------
    public static void beforeTaskSave(List<Onboarding_Task__c> rows, Map<Id, Onboarding_Task__c> oldMap) {
        for (Onboarding_Task__c t : rows) {
            Boolean nowDone = t.Status__c == 'Completed';
            Boolean wasDone = oldMap != null && oldMap.get(t.Id).Status__c == 'Completed';
            if (nowDone && !wasDone) t.Completed_On__c = System.now();
            if (!nowDone) t.Completed_On__c = null;
        }
    }

    public static void afterTaskSave(List<Onboarding_Task__c> rows) {
        Set<Id> onbIds = new Set<Id>();
        for (Onboarding_Task__c t : rows) onbIds.add(t.Onboarding__c);
        evaluateCompletion(onbIds);
    }

    public static void evaluateCompletion(Set<Id> onboardingIds) {
        List<Onboarding__c> onbs = [
            SELECT Id, Status__c, Employee__c, Employee__r.Status__c, Employee__r.Name, OwnerId,
                   (SELECT Status__c, Mandatory__c FROM Tasks__r)
            FROM Onboarding__c WHERE Id IN :onboardingIds AND Status__c NOT IN ('Cancelled', 'On Hold')
        ];
        List<Onboarding__c> updates = new List<Onboarding__c>();
        List<Employee__c> empUpdates = new List<Employee__c>();
        for (Onboarding__c o : onbs) {
            Integer openMandatory = 0;
            Integer started = 0;
            for (Onboarding_Task__c t : o.Tasks__r) {
                if (t.Mandatory__c && t.Status__c != 'Completed' && t.Status__c != 'Skipped') openMandatory++;
                if (t.Status__c != 'Not Started') started++;
            }
            if (openMandatory == 0 && !o.Tasks__r.isEmpty() && o.Status__c != 'Completed') {
                updates.add(new Onboarding__c(Id = o.Id, Status__c = 'Completed', Completed_On__c = Date.today()));
                if (o.Employee__r.Status__c == 'Pre-boarding' || o.Employee__r.Status__c == 'Onboarding') {
                    empUpdates.add(new Employee__c(Id = o.Employee__c, Status__c = 'Active'));
                }
                PS_Util.notify(o.OwnerId, 'Onboarding complete: ' + o.Employee__r.Name, 'All mandatory onboarding tasks are done.', o.Id);
            } else if (openMandatory > 0 && o.Status__c == 'Completed') {
                updates.add(new Onboarding__c(Id = o.Id, Status__c = 'In Progress', Completed_On__c = null));
            } else if (started > 0 && o.Employee__r.Status__c == 'Pre-boarding') {
                empUpdates.add(new Employee__c(Id = o.Employee__c, Status__c = 'Onboarding'));
            }
        }
        if (!updates.isEmpty()) update updates;
        if (!empUpdates.isEmpty()) update empUpdates;
    }
}
