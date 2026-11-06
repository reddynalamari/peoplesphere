trigger PS_ExpenseClaimTrigger on Expense_Claim__c (before insert, before update, after insert) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) {
        PS_LeaveService.beforeExpenseSave(Trigger.new);
    } else {
        for (Expense_Claim__c c : Trigger.new) {
            if (c.Status__c == 'Submitted') PS_Util.notify(c.Approver__c, 'Expense approval needed', 'Amount: ' + c.Amount__c, c.Id);
        }
    }
}
