trigger PS_EmployeeTrigger on Employee__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_EmployeeHandler.beforeSave(Trigger.new, Trigger.oldMap);
    else if (Trigger.isInsert) PS_EmployeeHandler.afterInsert(Trigger.new);
    else PS_EmployeeHandler.afterUpdate(Trigger.new, Trigger.oldMap);
}
