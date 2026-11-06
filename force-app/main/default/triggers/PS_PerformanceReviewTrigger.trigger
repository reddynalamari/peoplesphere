trigger PS_PerformanceReviewTrigger on Performance_Review__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_TalentService.beforeReviewSave(Trigger.new, Trigger.oldMap);
    else PS_TalentService.afterReviewSave(Trigger.new, Trigger.oldMap);
}
