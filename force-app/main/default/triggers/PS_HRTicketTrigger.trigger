trigger PS_HRTicketTrigger on HR_Ticket__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore && Trigger.isInsert) PS_TicketService.beforeInsert(Trigger.new);
    else if (Trigger.isBefore) PS_TicketService.beforeUpdate(Trigger.new, Trigger.oldMap);
    else PS_TicketService.afterSave(Trigger.new, Trigger.oldMap);
}
