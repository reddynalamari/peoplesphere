/**
 * Onboarding tracker endpoints (record page + HR pipeline).
 */
public inherited sharing class PS_OnboardingController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getOnboarding(Id recordId) {
        try {
            Id onbId = recordId;
            if (recordId != null && recordId.getSObjectType() == Employee__c.SObjectType) {
                List<Onboarding__c> o = [SELECT Id FROM Onboarding__c WHERE Employee__c = :recordId ORDER BY CreatedDate DESC LIMIT 1];
                if (o.isEmpty()) return null;
                onbId = o[0].Id;
            }
            Onboarding__c onb = [
                SELECT Id, Name, Status__c, Start_Date__c, Target_Completion_Date__c, Completed_On__c, Completion_Percent__c,
                       Total_Tasks__c, Completed_Tasks__c, Days_Elapsed__c, Welcome_Message__c, Employee__c, Employee__r.Name,
                       Employee__r.Designation__r.Name, Employee__r.Department__r.Name, Employee__r.Photo_URL__c, Buddy__r.Name,
                       Checklist_Template__r.Name,
                       (SELECT Id, Name, Assigned_Team__c, Assigned_To__c, Assigned_To__r.Name, Status__c, Due_Date__c, Mandatory__c,
                               Category__c, Description__c, Is_Overdue__c, Completed_On__c
                        FROM Tasks__r ORDER BY Sequence__c NULLS LAST, Due_Date__c)
                FROM Onboarding__c WHERE Id = :onbId];
            Map<String, List<Onboarding_Task__c>> byTeam = new Map<String, List<Onboarding_Task__c>>();
            Map<String, List<Integer>> teamProgress = new Map<String, List<Integer>>();
            for (Onboarding_Task__c t : onb.Tasks__r) {
                String team = t.Assigned_Team__c == null ? 'Other' : t.Assigned_Team__c;
                if (!byTeam.containsKey(team)) {
                    byTeam.put(team, new List<Onboarding_Task__c>());
                    teamProgress.put(team, new List<Integer>{ 0, 0 });
                }
                byTeam.get(team).add(t);
                List<Integer> p = teamProgress.get(team);
                p[1] = p[1] + 1;
                if (t.Status__c == 'Completed' || t.Status__c == 'Skipped') p[0] = p[0] + 1;
            }
            List<Map<String, Object>> teams = new List<Map<String, Object>>();
            for (String team : byTeam.keySet()) {
                List<Integer> p = teamProgress.get(team);
                teams.add(new Map<String, Object>{ 'team' => team, 'tasks' => byTeam.get(team), 'done' => p[0], 'total' => p[1],
                    'percent' => p[1] == 0 ? 0 : Math.round(p[0] * 100.0 / p[1]) });
            }
            List<Employee_Document__c> docs = [SELECT Id, Name, Document_Type__c, Verification_Status__c, Mandatory__c
                                               FROM Employee_Document__c WHERE Employee__c = :onb.Employee__c ORDER BY Mandatory__c DESC, Name];
            return new Map<String, Object>{ 'onboarding' => onb, 'teams' => teams, 'documents' => docs, 'canManage' => PS_Util.isHrUser() };
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void setTaskStatus(Id taskId, String status) {
        PS_PortalController.updateTaskStatus(taskId, status);
    }

    @AuraEnabled
    public static void verifyDocument(Id documentId, Boolean approve, String reason) {
        try {
            if (!PS_Util.isHrUser()) throw new PS_Util.PS_Exception('Only HR can verify documents.');
            update new Employee_Document__c(Id = documentId,
                Verification_Status__c = approve ? 'Verified' : 'Rejected',
                Verified_By__c = approve ? UserInfo.getUserId() : null, Verified_On__c = approve ? Date.today() : null,
                Rejection_Reason__c = approve ? null : reason);
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }
}
