/**
 * Shared helpers for PeopleSphere: current employee lookup, skills parsing,
 * working-day calculation, permission checks and in-app notifications.
 */
public without sharing class PS_Util {
    public static Boolean bypassTriggers = false;
    /** Set only by PS_GuestHrGateway: the public HR demo acts with HR rights on fictional data. */
    public static Boolean demoHrMode = false;
    private static Employee__c cachedCurrent;
    private static Boolean cachedIsHr;

    public static final Set<String> ACTIVE_STATUSES = new Set<String>{ 'Pre-boarding', 'Onboarding', 'Active', 'On Notice' };

    /** Employee record linked to the running user, or null. */
    public static Employee__c currentEmployee() {
        if (cachedCurrent == null) {
            List<Employee__c> rows = [
                SELECT Id, Name, Employee_ID__c, Department__c, Department__r.Name, Designation__c, Designation__r.Name,
                       Location__c, Location__r.Name, Manager__c, Manager__r.Name, Manager__r.User__c, Organization__c,
                       Status__c, Work_Mode__c, Skills__c, Photo_URL__c, Date_of_Joining__c, Work_Email__c,
                       Casual_Leave_Balance__c, Sick_Leave_Balance__c, Earned_Leave_Balance__c, Recognition_Points__c,
                       Profile_Completeness__c, Performance_Rating__c
                FROM Employee__c WHERE User__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            cachedCurrent = rows.isEmpty() ? null : rows[0];
        }
        return cachedCurrent;
    }

    public static Employee__c requireCurrentEmployee() {
        Employee__c e = currentEmployee();
        if (e == null) {
            throw new PS_Exception('Your user is not linked to an Employee record. Ask HR to set "Salesforce User" on your employee profile.');
        }
        return e;
    }

    /** True for users holding the PeopleSphere HR or Admin permission set (or System Administrator). */
    public static Boolean isHrUser() {
        if (demoHrMode) return true;
        if (cachedIsHr == null) {
            Integer n = [
                SELECT COUNT() FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND (PermissionSet.Name IN ('PeopleSphere_HR', 'PeopleSphere_Admin') OR PermissionSet.PermissionsModifyAllData = true)
            ];
            cachedIsHr = n > 0;
        }
        return cachedIsHr;
    }

    /** Active users holding the HR or Admin permission set - used for ticket routing. */
    /** Field-level check for sensitive fields (pay, attrition risk) that the HR demo may also see. */
    public static Boolean canSee(Schema.DescribeFieldResult f) {
        return demoHrMode || f.isAccessible();
    }

    public static List<Id> hrUserIds() {
        List<Id> ids = new List<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment
            WHERE PermissionSet.Name IN ('PeopleSphere_HR', 'PeopleSphere_Admin') AND Assignee.IsActive = true
            ORDER BY AssigneeId LIMIT 200
        ]) {
            if (!ids.contains(psa.AssigneeId)) ids.add(psa.AssigneeId);
        }
        return ids;
    }

    public static Set<String> splitSkills(String raw) {
        Set<String> out = new Set<String>();
        if (String.isBlank(raw)) return out;
        for (String s : raw.split('[;,\\n]')) {
            if (String.isNotBlank(s)) out.add(s.trim().toLowerCase());
        }
        return out;
    }

    public static Boolean isWeekend(Date d) {
        String day = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('E');
        return day == 'Sat' || day == 'Sun';
    }

    /** Holidays between two dates that apply globally or to one of the given locations. */
    public static Set<Date> holidays(Date startDate, Date endDate, Set<Id> locationIds) {
        Set<Date> out = new Set<Date>();
        for (Holiday__c h : [
            SELECT Holiday_Date__c FROM Holiday__c
            WHERE Holiday_Date__c >= :startDate AND Holiday_Date__c <= :endDate AND Optional__c = false
            AND (Location__c = null OR Location__c IN :locationIds)
        ]) {
            out.add(h.Holiday_Date__c);
        }
        return out;
    }

    public static List<Date> workingDates(Date startDate, Date endDate, Set<Date> holidayDates) {
        List<Date> out = new List<Date>();
        if (startDate == null || endDate == null || endDate < startDate) return out;
        for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
            if (!isWeekend(d) && !holidayDates.contains(d)) out.add(d);
        }
        return out;
    }

    public static String dateKey(Date d) {
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('yyyyMMdd');
    }

    private static Id notificationTypeId;
    private static Boolean notificationTypeLoaded = false;

    /** Sends a PeopleSphere bell notification. Failures never block business logic. */
    public static void notify(Set<Id> userIds, String title, String body, Id targetId) {
        userIds.remove(null);
        if (userIds.isEmpty() || targetId == null) return;
        try {
            if (!notificationTypeLoaded) {
                notificationTypeLoaded = true;
                List<CustomNotificationType> t = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'PeopleSphere_Alert' LIMIT 1];
                notificationTypeId = t.isEmpty() ? null : t[0].Id;
            }
            if (notificationTypeId == null || Limits.getCallouts() > 0) return;
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setNotificationTypeId(notificationTypeId);
            n.setTitle(title.abbreviate(250));
            n.setBody(String.isBlank(body) ? title : body.abbreviate(750));
            n.setTargetId(targetId);
            Set<String> recipients = new Set<String>();
            for (Id u : userIds) recipients.add(u);
            n.send(recipients);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'PeopleSphere notification skipped: ' + e.getMessage());
        }
    }

    public static void notify(Id userId, String title, String body, Id targetId) {
        notify(new Set<Id>{ userId }, title, body, targetId);
    }

    public static AuraHandledException auraError(Exception e) {
        String msg = e.getMessage();
        if (e instanceof DmlException) msg = ((DmlException) e).getDmlMessage(0);
        AuraHandledException ae = new AuraHandledException(msg);
        ae.setMessage(msg);
        return ae;
    }

    public class PS_Exception extends Exception {}
}
