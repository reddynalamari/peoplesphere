/**
 * Public HR Admin demo gateway for the PeopleSphere Experience Cloud site
 * (page /hr-admin). Guests act with HR rights over the FICTIONAL demo data so
 * anyone with the link AND the password can try every HR feature.
 *
 * Password protection is enforced on the server:
 *   - unlock(password) compares SHA-256(password) with PS_Demo_Setting__mdt
 *     and returns a signed token valid for 8 hours;
 *   - every other method requires that token (HMAC-SHA256 signed with a key
 *     derived from the stored hash and the org id), so calling the Apex
 *     directly without the password does not work either.
 *
 * It also refuses every caller that is not the site guest user. Never use
 * this pattern in an org that holds real employee data.
 */
public without sharing class PS_GuestHrGateway {

    @TestVisible private static final Long TOKEN_TTL_MS = 8L * 60 * 60 * 1000;

    private static String passwordHash() {
        PS_Demo_Setting__mdt s = PS_Demo_Setting__mdt.getInstance('Default');
        return s == null ? null : s.HR_Password_Hash__c;
    }

    private static String sign(String payload) {
        Blob key = Blob.valueOf(passwordHash() + ':' + UserInfo.getOrganizationId());
        return EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(payload), key));
    }

    @TestVisible
    private static Boolean validToken(String token) {
        if (String.isBlank(token) || !token.contains('.') || passwordHash() == null) return false;
        String expiry = token.substringBefore('.');
        try {
            if (Long.valueOf(expiry) < System.currentTimeMillis()) return false;
        } catch (Exception e) {
            return false;
        }
        return sign(expiry) == token.substringAfter('.');
    }

    private static void guard(String token) {
        if (UserInfo.getUserType() != 'Guest' && !Test.isRunningTest()) {
            throw new AuraHandledException('This endpoint is only available on the public demo site.');
        }
        if (!validToken(token)) {
            throw new AuraHandledException('HR_LOCKED: Your HR session has expired. Please enter the password again.');
        }
        PS_Util.demoHrMode = true;
    }

    /** Exchanges the HR password for a signed session token. */
    @AuraEnabled
    public static String unlock(String password) {
        String stored = passwordHash();
        if (String.isBlank(password) || stored == null) throw new AuraHandledException('Incorrect password.');
        String given = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(password)));
        if (given != stored.toLowerCase()) throw new AuraHandledException('Incorrect password.');
        String expiry = String.valueOf(System.currentTimeMillis() + TOKEN_TTL_MS);
        return expiry + '.' + sign(expiry);
    }

    @AuraEnabled
    public static Boolean checkToken(String token) {
        return validToken(token);
    }

    // dashboard & people
    @AuraEnabled public static Map<String, Object> getOverview(String token) { guard(token); return PS_DashboardController.getOverview(); }
    @AuraEnabled public static List<Map<String, Object>> searchEmployees(String term, String token) { guard(token); return PS_Employee360Controller.searchEmployees(term); }
    @AuraEnabled public static Map<String, Object> getEmployee360(Id employeeId, String token) {
        guard(token);
        if (employeeId == null) {
            Employee__c top = PS_ManagerController.largestTeamManager();
            employeeId = top == null ? null : top.Id;
        }
        return PS_Employee360Controller.getEmployee360(employeeId);
    }
    @AuraEnabled public static Map<String, Object> getOrgTree(Id departmentId, String token) { guard(token); return PS_OrgChartController.getOrgTree(departmentId); }

    // onboarding
    @AuraEnabled public static List<Map<String, Object>> getOpenOnboardings(String token) { guard(token); return PS_HrOpsController.getOpenOnboardings(); }
    @AuraEnabled public static Map<String, Object> getOnboarding(Id recordId, String token) { guard(token); return PS_OnboardingController.getOnboarding(recordId); }
    @AuraEnabled public static void setTaskStatus(Id taskId, String status, String token) { guard(token); PS_OnboardingController.setTaskStatus(taskId, status); }
    @AuraEnabled public static void verifyDocument(Id documentId, Boolean approve, String reason, String token) { guard(token); PS_OnboardingController.verifyDocument(documentId, approve, reason); }

    // approvals, team, reviews
    @AuraEnabled public static Map<String, Object> getHrOverview(String token) { guard(token); return PS_ManagerController.getHrOverview(); }
    @AuraEnabled public static void decideLeave(Id leaveId, Boolean approve, String comments, String token) { guard(token); PS_ManagerController.decideLeave(leaveId, approve, comments); }
    @AuraEnabled public static void decideExpense(Id claimId, Boolean approve, String comments, String token) { guard(token); PS_ManagerController.decideExpense(claimId, approve, comments); }
    @AuraEnabled public static void submitManagerReview(Id reviewId, Decimal rating, String feedback, Boolean promotion, Boolean complete, String token) {
        guard(token);
        PS_ManagerController.submitManagerReview(reviewId, rating, feedback, promotion, complete);
    }
    @AuraEnabled public static void updateTaskStatus(Id taskId, String status, String token) { guard(token); PS_PortalController.updateTaskStatus(taskId, status); }
    @AuraEnabled public static void giveRecognition(Id recipientId, String badge, String message, String token) {
        guard(token);
        insert new Recognition__c(Recipient__c = recipientId, Badge__c = badge, Message__c = message, Points__c = 10, Visibility__c = 'Public');
    }

    // service desk
    @AuraEnabled public static Map<String, Object> getTickets(String view, String token) { guard(token); return PS_HrOpsController.getTickets(view); }
    @AuraEnabled public static void updateTicket(Id ticketId, String status, String priority, String resolution, String token) { guard(token); PS_HrOpsController.updateTicket(ticketId, status, priority, resolution); }
    @AuraEnabled public static Integer runEscalation(String token) { guard(token); return PS_HrOpsController.runEscalation(); }

    // recruitment
    @AuraEnabled public static Map<String, Object> getPipeline(String token) { guard(token); return PS_HrOpsController.getPipeline(); }
    @AuraEnabled public static Map<String, Object> moveCandidate(Id candidateId, String stage, String token) { guard(token); return PS_HrOpsController.moveCandidate(candidateId, stage); }
    @AuraEnabled public static void setRequisitionStatus(Id requisitionId, String status, String token) { guard(token); PS_HrOpsController.setRequisitionStatus(requisitionId, status); }

    // data explorer
    @AuraEnabled public static List<Map<String, Object>> getObjects(String token) { guard(token); return PS_DataExplorerController.getObjects(); }
    @AuraEnabled public static Map<String, Object> getRecords(String objectApiName, String term, String token) { guard(token); return PS_DataExplorerController.getRecords(objectApiName, term); }

    // record editor: create / view / edit / delete any PeopleSphere record
    @AuraEnabled public static Map<String, Object> describeObject(String objectApiName, String token) { guard(token); return PS_RecordEditorController.describeObject(objectApiName); }
    @AuraEnabled public static Map<String, Object> getRecord(String objectApiName, Id recordId, String token) { guard(token); return PS_RecordEditorController.getRecord(objectApiName, recordId); }
    @AuraEnabled public static Id saveRecord(String objectApiName, Id recordId, String valuesJson, String token) { guard(token); return PS_RecordEditorController.saveRecord(objectApiName, recordId, valuesJson); }
    @AuraEnabled public static void deleteRecord(String objectApiName, Id recordId, String token) { guard(token); PS_RecordEditorController.deleteRecord(objectApiName, recordId); }
    @AuraEnabled public static List<Map<String, String>> searchLookup(String objectApiName, String term, String token) { guard(token); return PS_RecordEditorController.searchLookup(objectApiName, term); }

    // assistant (no intents blocked)
    @AuraEnabled public static PS_AssistantController.Answer ask(String question, String token) { guard(token); return PS_AssistantController.ask(question); }
    @AuraEnabled public static List<String> suggestions(String token) { guard(token); return PS_AssistantController.suggestions(); }
    @AuraEnabled public static HR_Ticket__c escalateToHr(String question, String assistantAnswer, String token) { guard(token); return PS_GuestGateway.escalateToHr(question, assistantAnswer); }
}
