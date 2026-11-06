/**
 * Exit management: notice-period calculation, coordinated HR / IT / Finance /
 * Manager clearance, asset recovery, pending-expense checks and final status
 * changes on the employee record.
 */
public without sharing class PS_OffboardingService {

    @TestVisible
    private static final List<List<Object>> DEFAULT_TASKS = new List<List<Object>>{
        new List<Object>{ 'Approve resignation and agree last working day', 'Manager', 'Clearance', 0, true },
        new List<Object>{ 'Knowledge transfer plan and handover', 'Manager', 'Knowledge Transfer', -14, true },
        new List<Object>{ 'Schedule exit interview', 'HR', 'Clearance', -7, true },
        new List<Object>{ 'Revoke system, email and SSO access', 'IT', 'Access', 0, true },
        new List<Object>{ 'Clear pending expenses and advances', 'Finance', 'Clearance', -3, true },
        new List<Object>{ 'Department clearance sign-off', 'Department', 'Clearance', -1, true },
        new List<Object>{ 'Compute and process full and final settlement', 'Finance', 'Settlement', 15, true },
        new List<Object>{ 'Issue experience and relieving letter', 'HR', 'Documentation', 0, true },
        new List<Object>{ 'Move record to alumni network', 'HR', 'Clearance', 30, false }
    };

    public static void beforeInsert(List<Exit_Process__c> rows) {
        Set<Id> empIds = new Set<Id>();
        for (Exit_Process__c x : rows) empIds.add(x.Employee__c);
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, Organization__r.Default_Notice_Period_Days__c,
                   (SELECT Id FROM Exit_Processes__r WHERE Status__c NOT IN ('Completed', 'Withdrawn', 'Rejected'))
            FROM Employee__c WHERE Id IN :empIds]);
        for (Exit_Process__c x : rows) {
            Employee__c e = emps.get(x.Employee__c);
            if (e != null && !e.Exit_Processes__r.isEmpty()) {
                x.addError('This employee already has an open exit process.');
                continue;
            }
            if (x.Resignation_Date__c == null) x.Resignation_Date__c = Date.today();
            if (x.Notice_Period_Days__c == null) {
                Decimal def = e?.Organization__r?.Default_Notice_Period_Days__c;
                x.Notice_Period_Days__c = def != null ? def : 60;
            }
            if (x.Last_Working_Day__c == null) x.Last_Working_Day__c = x.Resignation_Date__c.addDays(x.Notice_Period_Days__c.intValue());
            if (x.Status__c == null) x.Status__c = 'Submitted';
        }
    }

    public static void beforeUpdate(List<Exit_Process__c> rows, Map<Id, Exit_Process__c> oldMap) {
        Set<Id> closing = new Set<Id>();
        for (Exit_Process__c x : rows) {
            if ((x.Status__c == 'Completed' || x.Status__c == 'Settled') && x.Status__c != oldMap.get(x.Id).Status__c) closing.add(x.Id);
        }
        if (closing.isEmpty()) return;
        Map<Id, Integer> open = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Exit_Process__c p, COUNT(Id) n FROM Exit_Task__c
            WHERE Exit_Process__c IN :closing AND Mandatory__c = true AND Status__c NOT IN ('Completed', 'Skipped')
            GROUP BY Exit_Process__c
        ]) {
            open.put((Id) ar.get('p'), (Integer) ar.get('n'));
        }
        for (Exit_Process__c x : rows) {
            if (open.containsKey(x.Id)) x.addError(open.get(x.Id) + ' mandatory clearance task(s) are still open.');
            else if (x.Status__c == 'Settled' && x.Settlement_Date__c == null) x.Settlement_Date__c = Date.today();
        }
    }

    public static void afterInsert(List<Exit_Process__c> rows) {
        Set<Id> empIds = new Set<Id>();
        for (Exit_Process__c x : rows) empIds.add(x.Employee__c);
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, Name, Organization__c, Department__c, Location__c, Employment_Type__c, User__c, Manager__r.User__c,
                   (SELECT Id, Name, Asset_Tag__c, Asset_Type__c FROM Assets__r WHERE Status__c = 'Assigned'),
                   (SELECT Amount__c FROM Expense_Claims__r WHERE Status__c IN ('Submitted', 'Approved'))
            FROM Employee__c WHERE Id IN :empIds]);
        List<Checklist_Template__c> templates = [
            SELECT Id, Organization__c, Department__c, Location__c, Employment_Type__c, Duration_Days__c,
                   (SELECT Name, Assigned_Team__c, Category__c, Days_Offset__c, Mandatory__c, Sequence__c, Description__c
                    FROM Items__r ORDER BY Sequence__c NULLS LAST)
            FROM Checklist_Template__c WHERE Process_Type__c = 'Offboarding' AND Active__c = true
        ];

        List<Exit_Task__c> tasks = new List<Exit_Task__c>();
        List<Employee__c> empUpdates = new List<Employee__c>();
        List<Exit_Process__c> exitUpdates = new List<Exit_Process__c>();
        for (Exit_Process__c x : rows) {
            Employee__c e = emps.get(x.Employee__c);
            Checklist_Template__c tpl = PS_OnboardingService.bestTemplate(templates, e.Organization__c, e.Department__c, e.Location__c, e.Employment_Type__c);
            Integer seq = 1;
            if (tpl != null && !tpl.Items__r.isEmpty()) {
                for (Checklist_Template_Item__c i : tpl.Items__r) {
                    tasks.add(task(x, e, i.Name, i.Assigned_Team__c, i.Category__c,
                        i.Days_Offset__c == null ? 0 : i.Days_Offset__c.intValue(), i.Mandatory__c, seq++, i.Description__c));
                }
            } else {
                for (List<Object> t : DEFAULT_TASKS) {
                    tasks.add(task(x, e, (String) t[0], (String) t[1], (String) t[2], (Integer) t[3], (Boolean) t[4], seq++, null));
                }
            }
            for (Company_Asset__c a : e.Assets__r) {
                tasks.add(task(x, e, ('Return ' + a.Asset_Type__c + ' (' + a.Asset_Tag__c + ')'), 'IT', 'Clearance', -1, true, seq++,
                    'Collect asset ' + a.Name + ' before the last working day.'));
            }
            Decimal pending = 0;
            for (Expense_Claim__c c : e.Expense_Claims__r) pending += c.Amount__c == null ? 0 : c.Amount__c;
            exitUpdates.add(new Exit_Process__c(Id = x.Id, Pending_Assets__c = e.Assets__r.size(), Pending_Expenses__c = pending));
            if (x.Status__c != 'Withdrawn' && x.Status__c != 'Rejected') empUpdates.add(new Employee__c(Id = e.Id, Status__c = 'On Notice'));
            PS_Util.notify(new Set<Id>{ e.Manager__r?.User__c, UserInfo.getUserId() }, 'Exit initiated: ' + e.Name,
                'Last working day ' + x.Last_Working_Day__c.format() + '. Clearance tasks have been created.', x.Id);
        }
        insert tasks;
        update exitUpdates;
        if (!empUpdates.isEmpty()) update empUpdates;
    }

    public static void afterUpdate(List<Exit_Process__c> rows, Map<Id, Exit_Process__c> oldMap) {
        List<Employee__c> empUpdates = new List<Employee__c>();
        for (Exit_Process__c x : rows) {
            Exit_Process__c o = oldMap.get(x.Id);
            if (x.Status__c == o.Status__c) continue;
            if (x.Status__c == 'Completed') {
                empUpdates.add(new Employee__c(Id = x.Employee__c, Status__c = 'Exited', Exit_Date__c = x.Last_Working_Day__c,
                    Rehire_Eligible__c = x.Rehire_Eligible__c));
            } else if (x.Status__c == 'Withdrawn' || x.Status__c == 'Rejected') {
                empUpdates.add(new Employee__c(Id = x.Employee__c, Status__c = 'Active'));
            }
        }
        if (!empUpdates.isEmpty()) update empUpdates;
    }

    private static Exit_Task__c task(Exit_Process__c x, Employee__c e, String name, String team, String category,
                                     Integer offsetFromLwd, Boolean mandatory, Integer seq, String description) {
        Date due = x.Last_Working_Day__c.addDays(offsetFromLwd);
        if (due < Date.today()) due = Date.today();
        return new Exit_Task__c(Name = name.abbreviate(80), Exit_Process__c = x.Id, Assigned_Team__c = team, Category__c = category,
            Due_Date__c = due, Mandatory__c = mandatory, Sequence__c = seq, Description__c = description, Status__c = 'Not Started',
            Assigned_To__c = PS_OnboardingService.resolveAssignee(team, e.User__c, e.Manager__r?.User__c));
    }

    // ---- clearance task hooks -------------------------------------------
    public static void beforeTaskSave(List<Exit_Task__c> rows, Map<Id, Exit_Task__c> oldMap) {
        for (Exit_Task__c t : rows) {
            Boolean wasDone = oldMap != null && oldMap.get(t.Id).Status__c == 'Completed';
            if (t.Status__c == 'Completed' && !wasDone) t.Completed_On__c = System.now();
            if (t.Status__c != 'Completed') t.Completed_On__c = null;
        }
    }

    public static void afterTaskSave(List<Exit_Task__c> rows) {
        Set<Id> ids = new Set<Id>();
        for (Exit_Task__c t : rows) ids.add(t.Exit_Process__c);
        List<Exit_Process__c> updates = new List<Exit_Process__c>();
        for (Exit_Process__c x : [
            SELECT Id, Status__c, (SELECT Status__c, Mandatory__c FROM Clearance_Tasks__r)
            FROM Exit_Process__c WHERE Id IN :ids AND Status__c IN ('Submitted', 'Manager Approved', 'Clearance In Progress')
        ]) {
            Integer open = 0, done = 0;
            for (Exit_Task__c t : x.Clearance_Tasks__r) {
                if (t.Mandatory__c && t.Status__c != 'Completed' && t.Status__c != 'Skipped') open++;
                if (t.Status__c == 'Completed') done++;
            }
            if (open == 0 && !x.Clearance_Tasks__r.isEmpty()) updates.add(new Exit_Process__c(Id = x.Id, Status__c = 'Ready for Settlement'));
            else if (done > 0 && x.Status__c != 'Clearance In Progress') updates.add(new Exit_Process__c(Id = x.Id, Status__c = 'Clearance In Progress'));
        }
        if (!updates.isEmpty()) update updates;
    }

    // ---- asset hooks ----------------------------------------------------
    public static void beforeAssetSave(List<Company_Asset__c> rows, Map<Id, Company_Asset__c> oldMap) {
        for (Company_Asset__c a : rows) {
            Id oldOwner = oldMap == null ? null : oldMap.get(a.Id).Assigned_To__c;
            if (a.Assigned_To__c != null && a.Assigned_To__c != oldOwner) {
                a.Status__c = 'Assigned';
                a.Assigned_On__c = Date.today();
                a.Returned_On__c = null;
            } else if (a.Assigned_To__c == null && oldOwner != null) {
                if (a.Status__c == 'Assigned') a.Status__c = 'In Stock';
                a.Returned_On__c = Date.today();
                a.Return_Due_Date__c = null;
            }
        }
    }

    /** When an asset comes back, auto-complete the matching clearance task. */
    public static void afterAssetUpdate(List<Company_Asset__c> rows, Map<Id, Company_Asset__c> oldMap) {
        Map<Id, Set<String>> returnedTagsByEmp = new Map<Id, Set<String>>();
        for (Company_Asset__c a : rows) {
            Id oldOwner = oldMap.get(a.Id).Assigned_To__c;
            if (oldOwner != null && a.Assigned_To__c == null && a.Asset_Tag__c != null) {
                if (!returnedTagsByEmp.containsKey(oldOwner)) returnedTagsByEmp.put(oldOwner, new Set<String>());
                returnedTagsByEmp.get(oldOwner).add('(' + a.Asset_Tag__c + ')');
            }
        }
        if (returnedTagsByEmp.isEmpty()) return;
        List<Exit_Task__c> done = new List<Exit_Task__c>();
        for (Exit_Task__c t : [
            SELECT Id, Name, Exit_Process__r.Employee__c FROM Exit_Task__c
            WHERE Exit_Process__r.Employee__c IN :returnedTagsByEmp.keySet() AND Status__c != 'Completed' AND Name LIKE 'Return %'
        ]) {
            for (String tag : returnedTagsByEmp.get(t.Exit_Process__r.Employee__c)) {
                if (t.Name.contains(tag)) done.add(new Exit_Task__c(Id = t.Id, Status__c = 'Completed'));
            }
        }
        if (!done.isEmpty()) update done;
    }
}
