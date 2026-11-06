trigger PS_InterviewTrigger on Interview__c (after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    PS_TalentService.afterInterviewSave(Trigger.new);
}
