/**
 * Employee lifecycle automation: ID generation, duplicate checks, profile
 * completeness, employment history, record sharing, and kicking off
 * onboarding and mandatory learning.
 */
public without sharing class PS_EmployeeHandler {

    private static final Map<String, String> HISTORY_FIELDS = new Map<String, String>{
        'Department__c' => 'Transfer',
        'Designation__c' => 'Designation Change',
        'Manager__c' => 'Manager Change',
        'Location__c' => 'Location Change',
        'Status__c' => 'Status Change',
        'Annual_CTC__c' => 'Compensation Change'
    };

    private static final List<String> COMPLETENESS_FIELDS = new List<String>{
        'First_Name__c', 'Last_Name__c', 'Work_Email__c', 'Phone__c', 'Department__c', 'Designation__c',
        'Location__c', 'Manager__c', 'Date_of_Joining__c', 'Date_of_Birth__c', 'Emergency_Contact_Name__c',
        'Emergency_Contact_Phone__c', 'Skills__c', 'Blood_Group__c'
    };
    private static final List<String> VERIFICATION_FLAGS = new List<String>{
        'Education_Verified__c', 'Previous_Employment_Verified__c', 'Bank_Details_Verified__c', 'Handbook_Acknowledged__c'
    };

    public static void beforeSave(List<Employee__c> rows, Map<Id, Employee__c> oldMap) {
        Boolean isInsert = oldMap == null;
        for (Employee__c e : rows) {
            if (String.isBlank(e.Name)) {
                e.Name = (String.isBlank(e.First_Name__c) ? '' : e.First_Name__c + ' ') + (e.Last_Name__c == null ? '' : e.Last_Name__c);
            }
            if (String.isBlank(e.First_Name__c) && String.isBlank(e.Last_Name__c) && String.isNotBlank(e.Name)) {
                Integer sp = e.Name.indexOf(' ');
                e.First_Name__c = sp > 0 ? e.Name.substring(0, sp) : e.Name;
                e.Last_Name__c = sp > 0 ? e.Name.substring(sp + 1) : null;
            }
            if (e.Status__c == 'Exited' && e.Exit_Date__c == null) e.Exit_Date__c = Date.today();
            if (e.Background_Check_Status__c == null) e.Background_Check_Status__c = 'Not Started';
            e.Profile_Completeness__c = completeness(e);
        }
        if (isInsert) assignEmployeeIds(rows);
        checkDuplicateEmails(rows);
    }

    public static Decimal completeness(Employee__c e) {
        Integer filled = 0;
        Integer total = COMPLETENESS_FIELDS.size() + VERIFICATION_FLAGS.size() + 1;
        for (String f : COMPLETENESS_FIELDS) if (e.get(f) != null && String.valueOf(e.get(f)) != '') filled++;
        for (String f : VERIFICATION_FLAGS) if (e.get(f) == true) filled++;
        if (e.Background_Check_Status__c == 'Cleared') filled++;
        return Math.round((filled * 100.0) / total);
    }

    private static void assignEmployeeIds(List<Employee__c> rows) {
        Set<Id> orgIds = new Set<Id>();
        for (Employee__c e : rows) if (e.Organization__c != null) orgIds.add(e.Organization__c);
        Map<Id, Organization__c> orgs = new Map<Id, Organization__c>(
            [SELECT Id, Employee_ID_Prefix__c FROM Organization__c WHERE Id IN :orgIds]);
        Map<String, Integer> nextByPrefix = new Map<String, Integer>();
        for (Employee__c e : rows) {
            if (String.isNotBlank(e.Employee_ID__c)) continue;
            Organization__c org = orgs.get(e.Organization__c);
            String prefix = (org != null && String.isNotBlank(org.Employee_ID_Prefix__c)) ? org.Employee_ID_Prefix__c.toUpperCase() : 'PS';
            if (!nextByPrefix.containsKey(prefix)) {
                String pattern = prefix + '-%';
                Integer next = 1;
                for (Employee__c last : [SELECT Employee_ID__c FROM Employee__c WHERE Employee_ID__c LIKE :pattern ORDER BY Employee_ID__c DESC LIMIT 1]) {
                    try { next = Integer.valueOf(last.Employee_ID__c.substringAfter('-')) + 1; } catch (Exception ex) { next = 1; }
                }
                nextByPrefix.put(prefix, next);
            }
            Integer n = nextByPrefix.get(prefix);
            e.Employee_ID__c = prefix + '-' + String.valueOf(n).leftPad(5, '0');
            nextByPrefix.put(prefix, n + 1);
        }
    }

    private static void checkDuplicateEmails(List<Employee__c> rows) {
        Map<String, Employee__c> byEmail = new Map<String, Employee__c>();
        for (Employee__c e : rows) {
            if (String.isBlank(e.Work_Email__c)) continue;
            String key = e.Work_Email__c.toLowerCase();
            if (byEmail.containsKey(key)) e.Work_Email__c.addError('Duplicate work email in this batch.');
            byEmail.put(key, e);
        }
        if (byEmail.isEmpty()) return;
        for (Employee__c existing : [SELECT Id, Work_Email__c, Name FROM Employee__c WHERE Work_Email__c IN :byEmail.keySet()]) {
            Employee__c incoming = byEmail.get(existing.Work_Email__c.toLowerCase());
            if (incoming != null && incoming.Id != existing.Id) {
                incoming.Work_Email__c.addError('Work email already used by ' + existing.Name + '.');
            }
        }
    }

    public static void afterInsert(List<Employee__c> rows) {
        List<Employment_History__c> history = new List<Employment_History__c>();
        Set<Id> toOnboard = new Set<Id>();
        Set<Id> allIds = new Set<Id>();
        for (Employee__c e : rows) {
            allIds.add(e.Id);
            history.add(new Employment_History__c(
                Employee__c = e.Id, Event_Type__c = 'Joined',
                Effective_Date__c = e.Date_of_Joining__c != null ? e.Date_of_Joining__c : Date.today(),
                New_Value__c = e.Status__c, Changed_By__c = UserInfo.getUserId(),
                Notes__c = 'Employee record created.'));
            if (e.Status__c == 'Pre-boarding' || e.Status__c == 'Onboarding') toOnboard.add(e.Id);
        }
        insert history;
        syncShares(rows, null);
        if (!toOnboard.isEmpty()) PS_OnboardingService.startOnboarding(toOnboard);
        PS_LearningService.assignMandatory(allIds, 'Mandatory Rule');
    }

    public static void afterUpdate(List<Employee__c> rows, Map<Id, Employee__c> oldMap) {
        Set<Id> refIds = new Set<Id>();
        for (Employee__c e : rows) {
            Employee__c o = oldMap.get(e.Id);
            for (String f : new List<String>{ 'Department__c', 'Designation__c', 'Manager__c', 'Location__c' }) {
                if (e.get(f) != o.get(f)) {
                    refIds.add((Id) e.get(f));
                    refIds.add((Id) o.get(f));
                }
            }
        }
        refIds.remove(null);
        Map<Id, String> names = new Map<Id, String>();
        Map<Id, Decimal> levels = new Map<Id, Decimal>();
        if (!refIds.isEmpty()) {
            for (Department__c d : [SELECT Id, Name FROM Department__c WHERE Id IN :refIds]) names.put(d.Id, d.Name);
            for (Designation__c d : [SELECT Id, Name, Level__c FROM Designation__c WHERE Id IN :refIds]) {
                names.put(d.Id, d.Name);
                levels.put(d.Id, d.Level__c);
            }
            for (Location__c d : [SELECT Id, Name FROM Location__c WHERE Id IN :refIds]) names.put(d.Id, d.Name);
            for (Employee__c d : [SELECT Id, Name FROM Employee__c WHERE Id IN :refIds]) names.put(d.Id, d.Name);
        }

        List<Employment_History__c> history = new List<Employment_History__c>();
        Set<Id> reassignLearning = new Set<Id>();
        List<Employee__c> shareChanges = new List<Employee__c>();
        for (Employee__c e : rows) {
            Employee__c o = oldMap.get(e.Id);
            for (String f : HISTORY_FIELDS.keySet()) {
                Object nv = e.get(f);
                Object ov = o.get(f);
                if (nv == ov) continue;
                String eventType = HISTORY_FIELDS.get(f);
                if (f == 'Designation__c' && nv != null && ov != null
                        && levels.get((Id) nv) != null && levels.get((Id) ov) != null
                        && levels.get((Id) nv) > levels.get((Id) ov)) {
                    eventType = 'Promotion';
                }
                if (f == 'Status__c' && (nv == 'Exited' || nv == 'Alumni')) eventType = 'Exit';
                history.add(new Employment_History__c(
                    Employee__c = e.Id, Event_Type__c = eventType, Effective_Date__c = Date.today(),
                    Field_Changed__c = Schema.SObjectType.Employee__c.fields.getMap().get(f).getDescribe().getLabel(),
                    Previous_Value__c = display(ov, names), New_Value__c = display(nv, names),
                    Changed_By__c = UserInfo.getUserId()));
                if (f == 'Department__c' || f == 'Designation__c') reassignLearning.add(e.Id);
            }
            if (e.User__c != o.User__c || e.Manager__c != o.Manager__c) shareChanges.add(e);
        }
        if (!history.isEmpty()) insert history;
        if (!shareChanges.isEmpty()) syncShares(shareChanges, oldMap);
        if (!reassignLearning.isEmpty()) PS_LearningService.assignMandatory(reassignLearning, 'Transfer Rule');
    }

    private static String display(Object v, Map<Id, String> names) {
        if (v == null) return null;
        if (v instanceof Id && names.containsKey((Id) v)) return names.get((Id) v);
        return String.valueOf(v).abbreviate(255);
    }

    /**
     * Employee__c is Private. Grant the employee's own user read access to their
     * record (so the self-service portal and child records work) and the
     * manager's user read access to the team member.
     */
    public static void syncShares(List<Employee__c> rows, Map<Id, Employee__c> oldMap) {
        Set<Id> managerIds = new Set<Id>();
        for (Employee__c e : rows) if (e.Manager__c != null) managerIds.add(e.Manager__c);
        Map<Id, Employee__c> managers = new Map<Id, Employee__c>([SELECT Id, User__c FROM Employee__c WHERE Id IN :managerIds]);
        List<Employee__Share> shares = new List<Employee__Share>();
        for (Employee__c e : rows) {
            Set<Id> grantees = new Set<Id>();
            if (e.User__c != null) grantees.add(e.User__c);
            if (e.Manager__c != null && managers.get(e.Manager__c)?.User__c != null) grantees.add(managers.get(e.Manager__c).User__c);
            grantees.remove(e.OwnerId);
            for (Id u : grantees) {
                shares.add(new Employee__Share(ParentId = e.Id, UserOrGroupId = u, AccessLevel = 'Read', RowCause = 'Manual'));
            }
        }
        if (!shares.isEmpty()) Database.insert(shares, false);
    }
}
