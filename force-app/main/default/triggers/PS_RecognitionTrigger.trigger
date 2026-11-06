trigger PS_RecognitionTrigger on Recognition__c (before insert, after insert) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_TalentService.beforeRecognitionInsert(Trigger.new);
    else PS_TalentService.afterRecognitionInsert(Trigger.new);
}
