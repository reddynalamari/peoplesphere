trigger PS_CompensationRevisionTrigger on Compensation_Revision__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_TalentService.beforeCompensationSave(Trigger.new, Trigger.oldMap);
    else PS_TalentService.afterCompensationSave(Trigger.new, Trigger.oldMap);
}
