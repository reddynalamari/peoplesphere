trigger PS_PolicyAcknowledgementTrigger on Policy_Acknowledgement__c (before insert, after insert) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_TalentService.beforeAcknowledgementInsert(Trigger.new);
    else PS_TalentService.afterAcknowledgementInsert(Trigger.new);
}
