trigger PS_LeaveRequestTrigger on Leave_Request__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_LeaveService.beforeLeaveSave(Trigger.new, Trigger.oldMap);
    else PS_LeaveService.afterLeaveSave(Trigger.new, Trigger.oldMap);
}
