trigger PS_JobRequisitionTrigger on Job_Requisition__c (before insert, before update) {
    if (PS_Util.bypassTriggers) return;
    PS_TalentService.beforeRequisitionSave(Trigger.new, Trigger.oldMap);
}
