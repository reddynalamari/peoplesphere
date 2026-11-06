trigger PS_ExitProcessTrigger on Exit_Process__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore && Trigger.isInsert) PS_OffboardingService.beforeInsert(Trigger.new);
    else if (Trigger.isBefore) PS_OffboardingService.beforeUpdate(Trigger.new, Trigger.oldMap);
    else if (Trigger.isInsert) PS_OffboardingService.afterInsert(Trigger.new);
    else PS_OffboardingService.afterUpdate(Trigger.new, Trigger.oldMap);
}
