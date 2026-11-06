/**
 * Employee self-service workspace: everything an employee needs on one page
 * plus the actions they can take (leave, attendance, tickets, expenses,
 * policies, learning, recognition, surveys, goals, reviews, resignation).
 *
 * Every action is scoped to the running user's own Employee record.
 */
public inherited sharing class PS_PortalController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getMyWorkspace() {
        try {
            Map<String, Object> out = new Map<String, Object>();
            Employee__c me = PS_Util.currentEmployee();
            out.put('linked', me != null);
            out.put('userName', UserInfo.getFirstName());
            out.put('announcements', announcements(me));
            out.put('recognitionWall', recognitionWall());
            if (me == null) return out;
            out.put('employee', me);

            String todayKey = me.Id + '-' + PS_Util.dateKey(Date.today());
            List<Attendance__c> today = [SELECT Id, Check_In__c, Check_Out__c, Status__c, Late_Arrival__c, Hours_Worked__c, Work_Mode__c FROM Attendance__c WHERE Unique_Key__c = :todayKey];
            out.put('today', today.isEmpty() ? null : today[0]);
            out.put('recentAttendance', [SELECT Attendance_Date__c, Status__c, Hours_Worked__c, Late_Arrival__c FROM Attendance__c
                                         WHERE Employee__c = :me.Id AND Attendance_Date__c = LAST_N_DAYS:14 ORDER BY Attendance_Date__c DESC]);

            List<Onboarding__c> onb = [SELECT Id, Name, Status__c, Completion_Percent__c, Welcome_Message__c, Start_Date__c, Buddy__r.Name,
                                              (SELECT Id, Name, Assigned_Team__c, Status__c, Due_Date__c, Is_Overdue__c, Mandatory__c, Description__c, Assigned_To__c
                                               FROM Tasks__r ORDER BY Sequence__c)
                                       FROM Onboarding__c WHERE Employee__c = :me.Id AND Status__c IN ('Not Started', 'In Progress') ORDER BY CreatedDate DESC LIMIT 1];
            out.put('onboarding', onb.isEmpty() ? null : onb[0]);

            List<Onboarding_Task__c> myTasks = [SELECT Id, Name, Assigned_Team__c, Status__c, Due_Date__c, Is_Overdue__c, Employee_Name__c, Onboarding__c
                                                FROM Onboarding_Task__c WHERE Assigned_To__c = :UserInfo.getUserId()
                                                AND Status__c NOT IN ('Completed', 'Skipped') ORDER BY Due_Date__c NULLS LAST LIMIT 20];
            List<Exit_Task__c> myExitTasks = [SELECT Id, Name, Assigned_Team__c, Status__c, Due_Date__c, Is_Overdue__c, Exit_Process__r.Employee__r.Name
                                              FROM Exit_Task__c WHERE Assigned_To__c = :UserInfo.getUserId()
                                              AND Status__c NOT IN ('Completed', 'Skipped') ORDER BY Due_Date__c NULLS LAST LIMIT 20];
            out.put('myTasks', myTasks);
            out.put('myExitTasks', myExitTasks);

            out.put('enrollments', [SELECT Id, Course__c, Course__r.Name, Course__r.Category__c, Course__r.Duration_Hours__c, Course__r.Content_URL__c,
                                           Course__r.Total_Questions__c, Course__r.Mandatory__c, Status__c, Progress_Percent__c, Due_Date__c, Score__c, Is_Overdue__c
                                    FROM Learning_Enrollment__c WHERE Employee__c = :me.Id AND Status__c != 'Waived'
                                    ORDER BY Status__c, Due_Date__c NULLS LAST LIMIT 30]);
            out.put('certifications', [SELECT Id, Name, Expires_On__c, Status__c FROM Certification__c WHERE Employee__c = :me.Id ORDER BY Expires_On__c NULLS LAST LIMIT 10]);
            out.put('recommendations', PS_LearningService.recommend(me.Id, 4));

            // policies requiring acknowledgement of the current version
            Set<String> acked = new Set<String>();
            for (Policy_Acknowledgement__c a : [SELECT HR_Policy__c, Version__c FROM Policy_Acknowledgement__c WHERE Employee__c = :me.Id]) {
                acked.add(a.HR_Policy__c + '|' + a.Version__c);
            }
            List<HR_Policy__c> pending = new List<HR_Policy__c>();
            for (HR_Policy__c p : [SELECT Id, Name, Category__c, Summary__c, Version__c, Effective_Date__c FROM HR_Policy__c
                                   WHERE Active__c = true AND Requires_Acknowledgement__c = true ORDER BY Effective_Date__c DESC LIMIT 50]) {
                if (!acked.contains(p.Id + '|' + p.Version__c)) pending.add(p);
            }
            out.put('pendingPolicies', pending);

            out.put('myTickets', [SELECT Id, Name, Subject__c, Category__c, Priority__c, Status__c, SLA_Due__c, CreatedDate, Satisfaction_Rating__c, Resolution__c
                                  FROM HR_Ticket__c WHERE Employee__c = :me.Id ORDER BY CreatedDate DESC LIMIT 10]);
            out.put('myLeaves', [SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c, Number_of_Days__c, Status__c, Approver_Comments__c
                                 FROM Leave_Request__c WHERE Employee__c = :me.Id ORDER BY Start_Date__c DESC LIMIT 10]);
            out.put('myExpenses', [SELECT Id, Name, Category__c, Amount__c, Expense_Date__c, Status__c FROM Expense_Claim__c WHERE Employee__c = :me.Id ORDER BY CreatedDate DESC LIMIT 10]);
            out.put('myAssets', [SELECT Id, Name, Asset_Tag__c, Asset_Type__c, Assigned_On__c FROM Company_Asset__c WHERE Assigned_To__c = :me.Id]);
            out.put('goals', [SELECT Id, Name, Key_Result__c, Target_Value__c, Current_Value__c, Unit__c, Progress__c, Status__c, Due_Date__c
                              FROM Goal__c WHERE Employee__c = :me.Id AND Status__c NOT IN ('Achieved', 'Cancelled') ORDER BY Due_Date__c NULLS LAST LIMIT 10]);
            List<Performance_Review__c> openReview = [SELECT Id, Name, Review_Cycle__c, Review_Year__c, Status__c, Due_Date__c, Self_Rating__c, Self_Assessment__c
                                                      FROM Performance_Review__c WHERE Employee__c = :me.Id AND Status__c IN ('Not Started', 'Self Assessment')
                                                      ORDER BY Due_Date__c NULLS LAST LIMIT 1];
            out.put('openReview', openReview.isEmpty() ? null : openReview[0]);
            out.put('holidays', [SELECT Name, Holiday_Date__c, Optional__c FROM Holiday__c WHERE Holiday_Date__c >= TODAY
                                 AND (Location__c = null OR Location__c = :me.Location__c) ORDER BY Holiday_Date__c LIMIT 6]);
            out.put('activeSurvey', activeSurvey());
            out.put('exitProcess', [SELECT Id, Name, Status__c, Last_Working_Day__c, Clearance_Percent__c FROM Exit_Process__c
                                    WHERE Employee__c = :me.Id AND Status__c NOT IN ('Completed', 'Withdrawn', 'Rejected') LIMIT 1]);
            out.put('internalJobs', [SELECT Id, Name, Department__r.Name, Location__r.Name, Required_Skills__c, Employment_Type__c
                                     FROM Job_Requisition__c WHERE Status__c = 'Open' AND Internal_Posting__c = true ORDER BY Posted_On__c DESC LIMIT 5]);
            return out;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    private static List<Announcement__c> announcements(Employee__c me) {
        Id dept = me == null ? null : me.Department__c;
        return [SELECT Id, Name, Body__c, Category__c, Publish_Date__c, Pinned__c, Event_Date__c, Event_Location__c FROM Announcement__c
                WHERE (Publish_Date__c = null OR Publish_Date__c <= TODAY) AND (Expiry_Date__c = null OR Expiry_Date__c >= TODAY)
                AND (Department__c = null OR Department__c = :dept)
                ORDER BY Pinned__c DESC, Publish_Date__c DESC NULLS LAST LIMIT 8];
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> recognitionWall() {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (Recognition__c r : [SELECT Id, Badge__c, Message__c, Points__c, CreatedDate, Giver__r.Name, Recipient__r.Name, Recipient__r.Photo_URL__c
                                 FROM Recognition__c WHERE Visibility__c = 'Public' ORDER BY CreatedDate DESC LIMIT 12]) {
            out.add(new Map<String, Object>{ 'id' => r.Id, 'badge' => r.Badge__c, 'message' => r.Message__c, 'points' => r.Points__c,
                'when' => r.CreatedDate, 'from' => r.Giver__r?.Name, 'to' => r.Recipient__r?.Name, 'photo' => r.Recipient__r?.Photo_URL__c });
        }
        return out;
    }

    private static Pulse_Survey__c activeSurvey() {
        for (Pulse_Survey__c s : [SELECT Id, Name, Question__c, Survey_Type__c, Anonymous__c FROM Pulse_Survey__c
                                  WHERE Active__c = true AND (End_Date__c = null OR End_Date__c >= TODAY) ORDER BY CreatedDate DESC LIMIT 5]) {
            String key = PS_TalentService.respondentKey(s.Id, UserInfo.getUserId());
            if ([SELECT COUNT() FROM Survey_Response__c WHERE Respondent_Key__c = :key] == 0) return s;
        }
        return null;
    }

    // ------------------------------ actions -----------------------------
    @AuraEnabled
    public static Id applyLeave(String leaveType, Date startDate, Date endDate, Boolean halfDay, String reason) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Leave_Request__c l = new Leave_Request__c(Employee__c = me.Id, Leave_Type__c = leaveType, Start_Date__c = startDate,
                End_Date__c = endDate, Half_Day__c = halfDay == true, Reason__c = reason, Status__c = 'Submitted');
            insert l;
            return l.Id;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void cancelLeave(Id leaveId) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Leave_Request__c l = [SELECT Id, Employee__c, Status__c, Start_Date__c FROM Leave_Request__c WHERE Id = :leaveId];
            if (l.Employee__c != me.Id) throw new PS_Util.PS_Exception('You can only cancel your own leave.');
            if (l.Status__c == 'Approved' && l.Start_Date__c < Date.today()) throw new PS_Util.PS_Exception('Leave that has already started cannot be cancelled here. Contact HR.');
            l.Status__c = 'Cancelled';
            update l;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static Attendance__c checkIn(String workMode) {
        try { return PS_LeaveService.checkIn(PS_Util.requireCurrentEmployee().Id, workMode); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static Attendance__c checkOut() {
        try { return PS_LeaveService.checkOut(PS_Util.requireCurrentEmployee().Id); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static HR_Ticket__c raiseTicket(String subject, String description, String priority, String channel) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            HR_Ticket__c t = new HR_Ticket__c(Employee__c = me.Id, Subject__c = subject, Description__c = description,
                Priority__c = String.isBlank(priority) ? 'Medium' : priority, Channel__c = String.isBlank(channel) ? 'Portal' : channel);
            insert t;
            return [SELECT Id, Name, Subject__c, Category__c, Priority__c, Status__c, SLA_Due__c, AI_Suggested_Category__c, AI_Confidence__c,
                           Related_Policy__c, Related_Policy__r.Name, Related_Policy__r.Summary__c, Assigned_To__r.Name
                    FROM HR_Ticket__c WHERE Id = :t.Id];
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void rateTicket(Id ticketId, String rating, String feedback) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            HR_Ticket__c t = [SELECT Id, Employee__c, Status__c FROM HR_Ticket__c WHERE Id = :ticketId];
            if (t.Employee__c != me.Id) throw new PS_Util.PS_Exception('You can only rate your own tickets.');
            t.Satisfaction_Rating__c = rating;
            t.Feedback__c = feedback == null ? null : feedback.abbreviate(255);
            if (t.Status__c == 'Resolved') t.Status__c = 'Closed';
            update t;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void acknowledgePolicy(Id policyId) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Policy_Acknowledgement__c a = new Policy_Acknowledgement__c(HR_Policy__c = policyId, Employee__c = me.Id);
            Database.insert(a, true);
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static Id submitExpense(String category, Decimal amount, Date expenseDate, String description) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Expense_Claim__c c = new Expense_Claim__c(Employee__c = me.Id, Category__c = category, Amount__c = amount,
                Expense_Date__c = expenseDate, Description__c = description, Status__c = 'Submitted');
            insert c;
            return c.Id;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void giveRecognition(Id recipientId, String badge, String message) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            insert new Recognition__c(Giver__c = me.Id, Recipient__c = recipientId, Badge__c = badge, Message__c = message, Points__c = 10, Visibility__c = 'Public');
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void submitSurvey(Id surveyId, Integer score, String comment) {
        try {
            insert new Survey_Response__c(Pulse_Survey__c = surveyId, Score__c = score, Comment__c = comment);
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void updateTaskStatus(Id taskId, String status) {
        try {
            Id me = UserInfo.getUserId();
            if (taskId.getSObjectType() == Onboarding_Task__c.SObjectType) {
                Onboarding_Task__c t = [SELECT Id, Assigned_To__c FROM Onboarding_Task__c WHERE Id = :taskId];
                if (t.Assigned_To__c != me && !PS_Util.isHrUser()) throw new PS_Util.PS_Exception('This task is assigned to someone else.');
                t.Status__c = status;
                update t;
            } else {
                Exit_Task__c t = [SELECT Id, Assigned_To__c FROM Exit_Task__c WHERE Id = :taskId];
                if (t.Assigned_To__c != me && !PS_Util.isHrUser()) throw new PS_Util.PS_Exception('This task is assigned to someone else.');
                t.Status__c = status;
                update t;
            }
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void updateGoalProgress(Id goalId, Decimal currentValue) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Goal__c g = [SELECT Id, Employee__c, Target_Value__c FROM Goal__c WHERE Id = :goalId];
            if (g.Employee__c != me.Id) throw new PS_Util.PS_Exception('You can only update your own goals.');
            g.Current_Value__c = currentValue;
            if (g.Target_Value__c != null && currentValue >= g.Target_Value__c) g.Status__c = 'Achieved';
            else g.Status__c = 'On Track';
            update g;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void submitSelfAssessment(Id reviewId, Decimal rating, String assessment) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Performance_Review__c r = [SELECT Id, Employee__c, Status__c FROM Performance_Review__c WHERE Id = :reviewId];
            if (r.Employee__c != me.Id) throw new PS_Util.PS_Exception('You can only submit your own self-assessment.');
            r.Self_Rating__c = rating;
            r.Self_Assessment__c = assessment;
            r.Status__c = 'Manager Review';
            update r;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static Id submitResignation(String reason, Date requestedLastDay, String comments) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            Exit_Process__c x = new Exit_Process__c(Employee__c = me.Id, Exit_Type__c = 'Resignation', Exit_Reason__c = reason,
                Resignation_Date__c = Date.today(), Last_Working_Day__c = requestedLastDay, Manager_Comments__c = null,
                Exit_Interview_Notes__c = comments);
            insert x;
            return x.Id;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static Id applyInternalJob(Id requisitionId) {
        try {
            Employee__c me = PS_Util.requireCurrentEmployee();
            if ([SELECT COUNT() FROM Candidate__c WHERE Internal_Employee__c = :me.Id AND Job_Requisition__c = :requisitionId] > 0) {
                throw new PS_Util.PS_Exception('You have already applied for this position.');
            }
            Candidate__c c = new Candidate__c(Name = me.Name, Email__c = me.Work_Email__c, Job_Requisition__c = requisitionId,
                Source__c = 'Internal', Internal_Employee__c = me.Id, Skills__c = me.Skills__c == null ? null : me.Skills__c.abbreviate(255),
                Stage__c = 'Applied');
            insert c;
            return c.Id;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchColleagues(String term) {
        return PS_Employee360Controller.searchEmployees(term);
    }
}
