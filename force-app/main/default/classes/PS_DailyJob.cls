/**
 * Nightly automation. Schedule once with:  PS_DailyJob.scheduleDaily();
 *  - marks overdue learning, expires documents, reminds about expiring certifications
 *  - escalates HR tickets that breached SLA
 *  - recalculates the transparent attrition-risk indicator
 *  - posts birthday and work-anniversary announcements
 *  - reminds owners of overdue onboarding tasks
 */
public without sharing class PS_DailyJob implements Schedulable {

    public void execute(SchedulableContext ctx) {
        run();
    }

    public static String scheduleDaily() {
        return System.schedule('PeopleSphere Daily Job', '0 0 6 * * ?', new PS_DailyJob());
    }

    public static Map<String, Integer> run() {
        Map<String, Integer> stats = new Map<String, Integer>();
        stats.put('overdueEnrollments', PS_LearningService.markOverdue());
        stats.put('expiredDocuments', expireDocuments());
        stats.put('certificationReminders', certificationReminders());
        stats.put('escalatedTickets', PS_TicketService.escalateBreached());
        stats.put('riskRecalculated', recalculateAttritionRisk());
        stats.put('celebrations', postCelebrations());
        stats.put('onboardingReminders', onboardingReminders());
        return stats;
    }

    public static Integer expireDocuments() {
        List<Employee_Document__c> docs = [
            SELECT Id, Name, Employee__r.User__c FROM Employee_Document__c
            WHERE Expiry_Date__c < TODAY AND Verification_Status__c != 'Expired' LIMIT 2000];
        for (Employee_Document__c d : docs) {
            d.Verification_Status__c = 'Expired';
            PS_Util.notify(d.Employee__r.User__c, 'Document expired: ' + d.Name, 'Please upload a renewed copy.', d.Id);
        }
        if (!docs.isEmpty()) update docs;
        return docs.size();
    }

    public static Integer certificationReminders() {
        Date in30 = Date.today().addDays(30);
        List<Certification__c> certs = [
            SELECT Id, Name, Expires_On__c, Employee__r.User__c FROM Certification__c
            WHERE Expires_On__c = :in30 OR Expires_On__c = :Date.today().addDays(7) LIMIT 2000];
        for (Certification__c c : certs) {
            PS_Util.notify(c.Employee__r.User__c, 'Certification expiring: ' + c.Name, 'Expires on ' + c.Expires_On__c.format() + '. Re-certify to stay compliant.', c.Id);
        }
        return certs.size();
    }

    /**
     * Attrition risk is a transparent heuristic, not a prediction model:
     *  +2 latest rating <= 2.5     +1 no applied pay revision in 15 months (tenure > 1 yr)
     *  +1 no recognition points    +1 two or more manager changes in the last year
     *  +1 overdue mandatory training
     *  score >= 3 High, 2 Medium, otherwise Low.
     */
    public static Integer recalculateAttritionRisk() {
        List<Employee__c> emps = [
            SELECT Id, Performance_Rating__c, Recognition_Points__c, Date_of_Joining__c, Attrition_Risk__c,
                   (SELECT Id FROM Compensation_Revisions__r WHERE Status__c = 'Applied' AND Effective_Date__c = LAST_N_MONTHS:15),
                   (SELECT Id FROM Employment_History__r WHERE Event_Type__c = 'Manager Change' AND Effective_Date__c = LAST_N_DAYS:365),
                   (SELECT Id FROM Enrollments__r WHERE Status__c = 'Overdue')
            FROM Employee__c WHERE Status__c IN ('Active', 'Onboarding') LIMIT 5000];
        List<Employee__c> updates = new List<Employee__c>();
        for (Employee__c e : emps) {
            Integer score = 0;
            if (e.Performance_Rating__c != null && e.Performance_Rating__c <= 2.5) score += 2;
            Boolean tenured = e.Date_of_Joining__c != null && e.Date_of_Joining__c < Date.today().addYears(-1);
            if (tenured && e.Compensation_Revisions__r.isEmpty()) score += 1;
            if (e.Recognition_Points__c == null || e.Recognition_Points__c == 0) score += 1;
            if (e.Employment_History__r.size() >= 2) score += 1;
            if (!e.Enrollments__r.isEmpty()) score += 1;
            String risk = score >= 3 ? 'High' : (score == 2 ? 'Medium' : 'Low');
            if (risk != e.Attrition_Risk__c) updates.add(new Employee__c(Id = e.Id, Attrition_Risk__c = risk));
        }
        if (!updates.isEmpty()) update updates;
        return updates.size();
    }

    public static Integer postCelebrations() {
        Date today = Date.today();
        List<String> lines = new List<String>();
        for (Employee__c e : [
            SELECT Name, Date_of_Birth__c, Date_of_Joining__c FROM Employee__c
            WHERE Status__c IN ('Active', 'On Notice', 'Onboarding')
            AND ((CALENDAR_MONTH(Date_of_Birth__c) = :today.month() AND DAY_IN_MONTH(Date_of_Birth__c) = :today.day())
              OR (CALENDAR_MONTH(Date_of_Joining__c) = :today.month() AND DAY_IN_MONTH(Date_of_Joining__c) = :today.day()))
            LIMIT 200
        ]) {
            if (e.Date_of_Birth__c != null && e.Date_of_Birth__c.month() == today.month() && e.Date_of_Birth__c.day() == today.day()) {
                lines.add('Happy birthday, ' + e.Name + '!');
            }
            if (e.Date_of_Joining__c != null && e.Date_of_Joining__c.month() == today.month() && e.Date_of_Joining__c.day() == today.day()
                    && e.Date_of_Joining__c.year() < today.year()) {
                Integer yrs = today.year() - e.Date_of_Joining__c.year();
                lines.add('Congratulations ' + e.Name + ' on ' + yrs + (yrs == 1 ? ' year' : ' years') + ' with us!');
            }
        }
        if (lines.isEmpty()) return 0;
        String title = 'Celebrations - ' + today.format();
        if ([SELECT COUNT() FROM Announcement__c WHERE Name = :title] > 0) return 0;
        insert new Announcement__c(Name = title, Category__c = 'Celebration', Body__c = String.join(lines, '\n'),
            Publish_Date__c = today, Expiry_Date__c = today.addDays(1));
        return lines.size();
    }

    public static Integer onboardingReminders() {
        Map<Id, Integer> countByUser = new Map<Id, Integer>();
        Map<Id, Id> sampleTask = new Map<Id, Id>();
        for (Onboarding_Task__c t : [
            SELECT Id, Assigned_To__c FROM Onboarding_Task__c
            WHERE Is_Overdue__c = true AND Onboarding__r.Status__c = 'In Progress' AND Assigned_To__c != null LIMIT 2000
        ]) {
            countByUser.put(t.Assigned_To__c, (countByUser.containsKey(t.Assigned_To__c) ? countByUser.get(t.Assigned_To__c) : 0) + 1);
            sampleTask.put(t.Assigned_To__c, t.Id);
        }
        for (Id u : countByUser.keySet()) {
            PS_Util.notify(u, countByUser.get(u) + ' overdue onboarding task(s)', 'New joiners are waiting on you.', sampleTask.get(u));
        }
        return countByUser.size();
    }
}
