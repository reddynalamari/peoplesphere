/**
 * Public demo gateway for the PeopleSphere Experience Cloud site.
 *
 * Site guests are anonymous, so Salesforce's guest security model gives them
 * no record access. This class is the ONLY entry point a guest can call
 * (it is the only class in the PeopleSphere_Guest_Demo permission set). It:
 *   - refuses every caller that is not the site guest user,
 *   - runs the normal (inherited sharing) controllers without sharing,
 *   - scopes everything to the demo Employee record linked to the guest user,
 *   - blocks actions and analytics that would expose other people's data or
 *     break the shared demo (resignation, attrition risk, ticket lists).
 *
 * Never use this pattern with real employee data.
 */
public without sharing class PS_GuestGateway {

    private static final Set<String> BLOCKED_INTENTS = new Set<String>{ 'risk', 'open_tickets' };

    private static void guard() {
        if (UserInfo.getUserType() != 'Guest' && !Test.isRunningTest()) {
            throw new AuraHandledException('This endpoint is only available on the public demo site.');
        }
        if (PS_Util.currentEmployee() == null) {
            throw new AuraHandledException('The demo employee is not configured. Run scripts/apex/setup_public_demo.apex.');
        }
    }

    // ---------------- workspace ------------------------------------------
    @AuraEnabled public static Map<String, Object> getMyWorkspace() { guard(); return PS_PortalController.getMyWorkspace(); }
    @AuraEnabled public static Id applyLeave(String leaveType, Date startDate, Date endDate, Boolean halfDay, String reason) { guard(); return PS_PortalController.applyLeave(leaveType, startDate, endDate, halfDay, reason); }
    @AuraEnabled public static void cancelLeave(Id leaveId) { guard(); PS_PortalController.cancelLeave(leaveId); }
    @AuraEnabled public static Attendance__c checkIn(String workMode) { guard(); return PS_PortalController.checkIn(workMode); }
    @AuraEnabled public static Attendance__c checkOut() { guard(); return PS_PortalController.checkOut(); }
    @AuraEnabled public static HR_Ticket__c raiseTicket(String subject, String description, String priority, String channel) { guard(); return PS_PortalController.raiseTicket(subject, description, priority, channel); }
    @AuraEnabled public static void rateTicket(Id ticketId, String rating, String feedback) { guard(); PS_PortalController.rateTicket(ticketId, rating, feedback); }
    @AuraEnabled public static void acknowledgePolicy(Id policyId) { guard(); PS_PortalController.acknowledgePolicy(policyId); }
    @AuraEnabled public static Id submitExpense(String category, Decimal amount, Date expenseDate, String description) { guard(); return PS_PortalController.submitExpense(category, amount, expenseDate, description); }
    @AuraEnabled public static void giveRecognition(Id recipientId, String badge, String message) { guard(); PS_PortalController.giveRecognition(recipientId, badge, message); }
    @AuraEnabled public static void submitSurvey(Id surveyId, Integer score, String comment) { guard(); PS_PortalController.submitSurvey(surveyId, score, comment); }
    @AuraEnabled public static void updateGoalProgress(Id goalId, Decimal currentValue) { guard(); PS_PortalController.updateGoalProgress(goalId, currentValue); }
    @AuraEnabled public static void submitSelfAssessment(Id reviewId, Decimal rating, String assessment) { guard(); PS_PortalController.submitSelfAssessment(reviewId, rating, assessment); }
    @AuraEnabled public static Id applyInternalJob(Id requisitionId) { guard(); return PS_PortalController.applyInternalJob(requisitionId); }
    @AuraEnabled public static List<Map<String, Object>> searchColleagues(String term) { guard(); return PS_Employee360Controller.searchEmployees(term); }
    @AuraEnabled public static List<Map<String, Object>> searchEmployees(String term) { return searchColleagues(term); }

    @AuraEnabled
    public static void updateTaskStatus(Id taskId, String status) {
        guard();
        // guests may only tick tasks assigned to the demo user itself
        Id owner = taskId.getSObjectType() == Onboarding_Task__c.SObjectType
            ? [SELECT Assigned_To__c FROM Onboarding_Task__c WHERE Id = :taskId].Assigned_To__c
            : [SELECT Assigned_To__c FROM Exit_Task__c WHERE Id = :taskId].Assigned_To__c;
        if (owner != UserInfo.getUserId()) throw new AuraHandledException('Only tasks assigned to you can be completed.');
        PS_PortalController.updateTaskStatus(taskId, status);
    }

    @AuraEnabled
    public static Id submitResignation(String reason, Date requestedLastDay, String comments) {
        guard();
        throw new AuraHandledException('Resignation is disabled on the public demo so the demo employee stays active.');
    }

    // ---------------- learning -------------------------------------------
    @AuraEnabled public static Id selfEnroll(Id courseId) { guard(); return PS_LearningController.selfEnroll(courseId); }
    @AuraEnabled public static void markContentComplete(Id enrollmentId) { guard(); PS_LearningController.markContentComplete(enrollmentId); }
    @AuraEnabled public static PS_LearningService.Quiz getQuiz(Id enrollmentId) { guard(); return PS_LearningController.getQuiz(enrollmentId); }
    @AuraEnabled public static PS_LearningService.QuizResult submitQuiz(Id enrollmentId, Map<String, String> answers) { guard(); return PS_LearningController.submitQuiz(enrollmentId, answers); }

    // ---------------- profile, org chart, assistant -----------------------
    @AuraEnabled
    public static Map<String, Object> getEmployee360(Id employeeId) {
        guard();
        Id me = PS_Util.currentEmployee().Id;
        if (employeeId != null && employeeId != me) throw new AuraHandledException('On the public demo you can only open your own profile.');
        return PS_Employee360Controller.getEmployee360(me);
    }

    @AuraEnabled public static Map<String, Object> getOrgTree(Id departmentId) { guard(); return PS_OrgChartController.getOrgTree(departmentId); }
    @AuraEnabled public static List<String> suggestions() { return PS_AssistantController.suggestions(); }

    @AuraEnabled
    public static PS_AssistantController.Answer ask(String question) {
        guard();
        PS_AssistantController.Answer a = PS_AssistantController.ask(question);
        if (BLOCKED_INTENTS.contains(a.intent)) {
            a = new PS_AssistantController.Answer();
            a.intent = 'blocked';
            a.text = 'That report is available to HR users inside Salesforce, not on the public demo. Try a policy question or "Headcount by department".';
        }
        return a;
    }

    @AuraEnabled public static HR_Ticket__c escalateToHr(String question, String assistantAnswer) { guard(); return PS_AssistantController.escalateToHr(question, assistantAnswer); }
}
