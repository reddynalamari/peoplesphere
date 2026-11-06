trigger PS_CandidateTrigger on Candidate__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_TalentService.beforeCandidateSave(Trigger.new, Trigger.oldMap);
    else PS_TalentService.afterCandidateSave(Trigger.new, Trigger.oldMap);
}
