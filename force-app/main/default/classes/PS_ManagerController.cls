/**
 * Manager workspace: team roster with today's status, approvals queue,
 * reviews awaiting the manager, team onboarding and learning compliance.
 */
public inherited sharing class PS_ManagerController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getTeamOverview() {
        try {
            return buildOverview(PS_Util.currentEmployee(), false);
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    /** HR view: every pending approval in the organization plus the largest team. */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getHrOverview() {
        try {
            if (!PS_Util.isHrUser()) throw new PS_Util.PS_Exception('Only HR can see organization-wide approvals.');
            return buildOverview(largestTeamManager(), true);
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    public static Employee__c largestTeamManager() {
        for (AggregateResult ar : [SELECT Manager__c m, COUNT(Id) n FROM Employee__c WHERE Manager__c != null AND Status__c IN :PS_Util.ACTIVE_STATUSES
                                   GROUP BY Manager__c ORDER BY COUNT(Id) DESC LIMIT 1]) {
            Id managerId = (Id) ar.get('m');
            return [SELECT Id, Name FROM Employee__c WHERE Id = :managerId];
        }
        return null;
    }

    public static Map<String, Object> buildOverview(Employee__c me, Boolean orgWide) {
        {
            Map<String, Object> out = new Map<String, Object>();
            out.put('linked', me != null);
            out.put('orgWide', orgWide);
            out.put('managerName', me == null ? null : me.Name);
            Id myUser = UserInfo.getUserId();

            if (orgWide) {
                out.put('leaveApprovals', [SELECT Id, Name, Employee__r.Name, Employee__r.Photo_URL__c, Leave_Type__c, Start_Date__c, End_Date__c,
                                                  Number_of_Days__c, Reason__c, CreatedDate
                                           FROM Leave_Request__c WHERE Status__c = 'Submitted' ORDER BY Start_Date__c LIMIT 100]);
                out.put('expenseApprovals', [SELECT Id, Name, Employee__r.Name, Category__c, Amount__c, Expense_Date__c, Description__c, Receipt_Attached__c
                                             FROM Expense_Claim__c WHERE Status__c = 'Submitted' ORDER BY CreatedDate LIMIT 100]);
                out.put('myTasks', [SELECT Id, Name, Employee_Name__c, Assigned_Team__c, Due_Date__c, Status__c, Is_Overdue__c
                                    FROM Onboarding_Task__c WHERE Status__c NOT IN ('Completed', 'Skipped') AND Onboarding__r.Status__c = 'In Progress'
                                    ORDER BY Due_Date__c LIMIT 40]);
            } else {
                out.put('leaveApprovals', [SELECT Id, Name, Employee__r.Name, Employee__r.Photo_URL__c, Leave_Type__c, Start_Date__c, End_Date__c,
                                                  Number_of_Days__c, Reason__c, CreatedDate
                                           FROM Leave_Request__c WHERE Approver__c = :myUser AND Status__c = 'Submitted' ORDER BY Start_Date__c LIMIT 50]);
                out.put('expenseApprovals', [SELECT Id, Name, Employee__r.Name, Category__c, Amount__c, Expense_Date__c, Description__c, Receipt_Attached__c
                                             FROM Expense_Claim__c WHERE Approver__c = :myUser AND Status__c = 'Submitted' ORDER BY CreatedDate LIMIT 50]);
                out.put('myTasks', [SELECT Id, Name, Employee_Name__c, Assigned_Team__c, Due_Date__c, Status__c, Is_Overdue__c
                                    FROM Onboarding_Task__c WHERE Assigned_To__c = :myUser AND Status__c NOT IN ('Completed', 'Skipped') ORDER BY Due_Date__c LIMIT 30]);
            }
            if (me == null) return out;

            List<Employee__c> team = [
                SELECT Id, Name, Employee_ID__c, Photo_URL__c, Status__c, Designation__r.Name, Work_Mode__c, Performance_Rating__c,
                       Casual_Leave_Balance__c, Earned_Leave_Balance__c, Recognition_Points__c, Date_of_Joining__c,
                       (SELECT Status__c, Check_In__c, Late_Arrival__c FROM Attendance__r WHERE Attendance_Date__c = TODAY LIMIT 1),
                       (SELECT Status__c, Is_Overdue__c, Course__r.Mandatory__c FROM Enrollments__r WHERE Status__c != 'Waived'),
                       (SELECT Completion_Percent__c, Status__c FROM Onboardings__r WHERE Status__c IN ('Not Started', 'In Progress') LIMIT 1),
                       (SELECT Id, Status__c, Review_Cycle__c, Review_Year__c, Self_Rating__c, Self_Assessment__c, Due_Date__c, Is_Overdue__c
                        FROM Performance_Reviews__r WHERE Status__c IN ('Manager Review', 'Calibration', 'Self Assessment', 'Not Started') ORDER BY Due_Date__c LIMIT 1)
                FROM Employee__c WHERE Manager__c = :me.Id AND Status__c IN :PS_Util.ACTIVE_STATUSES ORDER BY Name LIMIT 200];

            List<Map<String, Object>> rows = new List<Map<String, Object>>();
            List<Map<String, Object>> reviewQueue = new List<Map<String, Object>>();
            Integer present = 0, onLeave = 0, overdueTraining = 0;
            Decimal ratingSum = 0; Integer rated = 0;
            for (Employee__c e : team) {
                String todayStatus = e.Attendance__r.isEmpty() ? 'Not checked in' : e.Attendance__r[0].Status__c;
                if (!e.Attendance__r.isEmpty() && (todayStatus == 'Present' || todayStatus == 'Work From Home')) present++;
                if (todayStatus == 'On Leave') onLeave++;
                Integer mand = 0, mandDone = 0, overdue = 0;
                for (Learning_Enrollment__c le : e.Enrollments__r) {
                    if (le.Is_Overdue__c || le.Status__c == 'Overdue') overdue++;
                    if (le.Course__r.Mandatory__c) { mand++; if (le.Status__c == 'Completed') mandDone++; }
                }
                overdueTraining += overdue;
                if (e.Performance_Rating__c != null) { ratingSum += e.Performance_Rating__c; rated++; }
                rows.add(new Map<String, Object>{
                    'id' => e.Id, 'name' => e.Name, 'employeeId' => e.Employee_ID__c, 'photo' => e.Photo_URL__c, 'status' => e.Status__c,
                    'designation' => e.Designation__r?.Name, 'today' => todayStatus,
                    'late' => !e.Attendance__r.isEmpty() && e.Attendance__r[0].Late_Arrival__c,
                    'rating' => e.Performance_Rating__c, 'compliance' => mand == 0 ? 100 : Math.round(mandDone * 100.0 / mand),
                    'overdueTraining' => overdue, 'leaveBalance' => nz(e.Casual_Leave_Balance__c) + nz(e.Earned_Leave_Balance__c),
                    'points' => e.Recognition_Points__c,
                    'onboarding' => e.Onboardings__r.isEmpty() ? null : e.Onboardings__r[0].Completion_Percent__c });
                if (!e.Performance_Reviews__r.isEmpty()) {
                    Performance_Review__c r = e.Performance_Reviews__r[0];
                    reviewQueue.add(new Map<String, Object>{ 'id' => r.Id, 'employee' => e.Name, 'cycle' => r.Review_Cycle__c + ' ' + r.Review_Year__c,
                        'status' => r.Status__c, 'selfRating' => r.Self_Rating__c, 'selfAssessment' => r.Self_Assessment__c,
                        'due' => r.Due_Date__c, 'overdue' => r.Is_Overdue__c, 'ready' => r.Status__c == 'Manager Review' });
                }
            }
            out.put('team', rows);
            out.put('reviewQueue', reviewQueue);
            out.put('kpis', new Map<String, Object>{
                'teamSize' => team.size(), 'present' => present, 'onLeave' => onLeave, 'overdueTraining' => overdueTraining,
                'pendingApprovals' => ((List<SObject>) out.get('leaveApprovals')).size() + ((List<SObject>) out.get('expenseApprovals')).size(),
                'avgRating' => rated == 0 ? null : (ratingSum / rated).setScale(1)
            });
            out.put('teamGoals', [SELECT Id, Name, Employee__r.Name, Status__c, Progress__c, Due_Date__c FROM Goal__c
                                  WHERE Employee__r.Manager__c = :me.Id AND Status__c NOT IN ('Achieved', 'Cancelled') ORDER BY Due_Date__c NULLS LAST LIMIT 20]);
            out.put('upcomingLeave', [SELECT Employee__r.Name, Leave_Type__c, Start_Date__c, End_Date__c FROM Leave_Request__c
                                      WHERE Employee__r.Manager__c = :me.Id AND Status__c = 'Approved' AND End_Date__c >= TODAY AND Start_Date__c = NEXT_N_DAYS:30
                                      ORDER BY Start_Date__c LIMIT 20]);
            return out;
        }
    }

    @AuraEnabled
    public static void decideLeave(Id leaveId, Boolean approve, String comments) {
        try { PS_LeaveService.decideLeave(leaveId, approve, comments); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void decideExpense(Id claimId, Boolean approve, String comments) {
        try { PS_LeaveService.decideExpense(claimId, approve, comments); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void submitManagerReview(Id reviewId, Decimal rating, String feedback, Boolean promotion, Boolean complete) {
        try { new Elevated().submitReview(reviewId, rating, feedback, promotion, complete); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    /** Managers have read access to team records; review edits are authorised explicitly here. */
    private without sharing class Elevated {
        void submitReview(Id reviewId, Decimal rating, String feedback, Boolean promotion, Boolean complete) {
            Employee__c me = PS_Util.demoHrMode ? null : PS_Util.requireCurrentEmployee();
            Performance_Review__c r = [SELECT Id, Employee__r.Manager__c, Reviewer__c FROM Performance_Review__c WHERE Id = :reviewId];
            if (r.Employee__r.Manager__c != me?.Id && r.Reviewer__c != me?.Id && !PS_Util.isHrUser()) {
                throw new PS_Util.PS_Exception('Only the reporting manager or assigned reviewer can submit this review.');
            }
            r.Manager_Rating__c = rating;
            r.Manager_Feedback__c = feedback;
            r.Promotion_Recommended__c = promotion == true;
            if (r.Reviewer__c == null && me != null) r.Reviewer__c = me.Id;
            r.Status__c = complete == true ? 'Completed' : 'Calibration';
            update r;
        }
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }
}
