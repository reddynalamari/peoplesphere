trigger PS_ExitTaskTrigger on Exit_Task__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_OffboardingService.beforeTaskSave(Trigger.new, Trigger.oldMap);
    else PS_OffboardingService.afterTaskSave(Trigger.new);
}
