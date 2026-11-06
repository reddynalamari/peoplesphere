@IsTest
private class PS_OperationsTest {

    @IsTest
    static void leaveApprovalDeductsBalanceAndMarksAttendance() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Date mon = PS_TestFactory.nextMonday();
        Leave_Request__c l = new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = mon, End_Date__c = mon.addDays(1));
        insert l;
        l = [SELECT Number_of_Days__c, Approver__c, Status__c FROM Leave_Request__c WHERE Id = :l.Id];
        System.assertEquals(2, l.Number_of_Days__c);
        System.assertEquals(UserInfo.getUserId(), l.Approver__c);

        Test.startTest();
        PS_LeaveService.decideLeave(l.Id, true, 'Enjoy');
        System.assertEquals(10, [SELECT Casual_Leave_Balance__c FROM Employee__c WHERE Id = :w.employee.Id].Casual_Leave_Balance__c);
        System.assertEquals(2, [SELECT COUNT() FROM Attendance__c WHERE Employee__c = :w.employee.Id AND Status__c = 'On Leave']);
        update new Leave_Request__c(Id = l.Id, Status__c = 'Cancelled');
        Test.stopTest();
        System.assertEquals(12, [SELECT Casual_Leave_Balance__c FROM Employee__c WHERE Id = :w.employee.Id].Casual_Leave_Balance__c);
    }

    @IsTest
    static void leaveValidationRules() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Date mon = PS_TestFactory.nextMonday();
        insert new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Sick Leave', Start_Date__c = mon, End_Date__c = mon);
        List<Leave_Request__c> bad = new List<Leave_Request__c>{
            new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = mon, End_Date__c = mon),                   // overlap
            new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Earned Leave', Start_Date__c = mon.addDays(14), End_Date__c = mon.addDays(60)), // balance
            new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Unpaid Leave', Start_Date__c = mon.addDays(5), End_Date__c = mon.addDays(6)),   // weekend only
            new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = mon.addDays(3), End_Date__c = mon.addDays(2)),   // reversed
            new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = mon.addDays(8), End_Date__c = mon.addDays(9), Half_Day__c = true)
        };
        List<Database.SaveResult> res = Database.insert(bad, false);
        for (Database.SaveResult r : res) System.assert(!r.isSuccess(), 'expected failure');
        Leave_Request__c half = new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Work From Home', Start_Date__c = mon.addDays(8), End_Date__c = mon.addDays(8), Half_Day__c = true);
        insert half;
        System.assertEquals(0.5, [SELECT Number_of_Days__c FROM Leave_Request__c WHERE Id = :half.Id].Number_of_Days__c);
        insert new Holiday__c(Name = 'Festival', Holiday_Date__c = mon.addDays(15));
        Leave_Request__c spanning = new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Unpaid Leave', Start_Date__c = mon.addDays(14), End_Date__c = mon.addDays(16));
        insert spanning;
        System.assertEquals(2, [SELECT Number_of_Days__c FROM Leave_Request__c WHERE Id = :spanning.Id].Number_of_Days__c);
    }

    @IsTest
    static void attendanceCheckInOutAndLateDetection() {
        PS_TestFactory.World w = PS_TestFactory.world();
        update new Location__c(Id = w.loc.Id, Office_Start_Time__c = '00:00', Late_Grace_Minutes__c = 0);
        Test.startTest();
        Attendance__c a = PS_LeaveService.checkIn(w.employee.Id, 'Office');
        System.assertNotEquals(null, a.Check_In__c);
        try { PS_LeaveService.checkIn(w.employee.Id, 'Office'); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(e.getMessage().contains('already')); }
        a = PS_LeaveService.checkOut(w.employee.Id);
        System.assertNotEquals(null, a.Check_Out__c);
        try { PS_LeaveService.checkOut(w.manager.Id); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(e.getMessage().contains('Check in')); }
        Test.stopTest();
        Attendance__c saved = [SELECT Unique_Key__c, Late_Arrival__c FROM Attendance__c WHERE Id = :a.Id];
        System.assert(saved.Unique_Key__c.startsWith(w.employee.Id));
    }

    @IsTest
    static void expenseApprovalFlow() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Expense_Claim__c c = new Expense_Claim__c(Employee__c = w.employee.Id, Category__c = 'Food', Amount__c = 250, Expense_Date__c = Date.today());
        insert c;
        System.assertEquals(UserInfo.getUserId(), [SELECT Approver__c FROM Expense_Claim__c WHERE Id = :c.Id].Approver__c);
        PS_LeaveService.decideExpense(c.Id, false, 'Missing receipt');
        System.assertEquals('Rejected', [SELECT Status__c FROM Expense_Claim__c WHERE Id = :c.Id].Status__c);
        try { PS_LeaveService.decideExpense(c.Id, true, null); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(e.getMessage().contains('submitted')); }
        try {
            insert new Expense_Claim__c(Employee__c = w.employee.Id, Category__c = 'Food', Amount__c = -1, Expense_Date__c = Date.today().addDays(3));
            System.assert(false);
        } catch (DmlException e) { System.assert(true); }
    }

    @IsTest
    static void ticketsAreClassifiedRoutedAndEscalated() {
        PS_TestFactory.World w = PS_TestFactory.world();
        HR_Policy__c pol = new HR_Policy__c(Name = 'Payroll Policy', Category__c = 'Compensation', Active__c = true, Policy_Body__c = 'Salary is credited on the last working day.');
        insert pol;
        Test.setFixedSearchResults(new List<Id>{ pol.Id });
        HR_Ticket__c t = new HR_Ticket__c(Employee__c = w.employee.Id, Subject__c = 'Salary not credited - urgent', Description__c = 'My salary for this month is not credited yet');
        HR_Ticket__c g = new HR_Ticket__c(Employee__c = w.employee.Id, Subject__c = 'Complaint', Description__c = 'I want to report harassment by a colleague');
        insert new List<HR_Ticket__c>{ t, g };
        t = [SELECT Category__c, Priority__c, SLA_Due__c, Assigned_To__c, AI_Confidence__c, Related_Policy__c FROM HR_Ticket__c WHERE Id = :t.Id];
        System.assertEquals('Payroll', t.Category__c);
        System.assertEquals('High', t.Priority__c);
        System.assertNotEquals(null, t.SLA_Due__c);
        System.assertNotEquals(null, t.Assigned_To__c);
        System.assertEquals(pol.Id, t.Related_Policy__c);
        g = [SELECT Category__c, Priority__c, Confidential__c FROM HR_Ticket__c WHERE Id = :g.Id];
        System.assertEquals('Critical', g.Priority__c);
        System.assert(g.Confidential__c);

        Test.startTest();
        try { update new HR_Ticket__c(Id = t.Id, Status__c = 'Resolved'); System.assert(false); } catch (DmlException e) { System.assert(e.getMessage().contains('resolution')); }
        update new HR_Ticket__c(Id = t.Id, Status__c = 'In Progress', Priority__c = 'Low');
        System.assertNotEquals(null, [SELECT First_Response_At__c FROM HR_Ticket__c WHERE Id = :t.Id].First_Response_At__c);
        update new HR_Ticket__c(Id = t.Id, Status__c = 'Resolved', Resolution__c = 'Processed by payroll');
        update new HR_Ticket__c(Id = g.Id, SLA_Due__c = System.now().addHours(-1));
        System.assertEquals(1, PS_TicketService.escalateBreached());
        Test.stopTest();
        g = [SELECT Status__c, Escalated__c, Escalation_Level__c FROM HR_Ticket__c WHERE Id = :g.Id];
        System.assertEquals('Escalated', g.Status__c);
        System.assertEquals(1, g.Escalation_Level__c);
        System.assertNotEquals(null, [SELECT Resolved_On__c FROM HR_Ticket__c WHERE Id = :t.Id].Resolved_On__c);
    }

    @IsTest
    static void classifierAndUtilities() {
        PS_TicketService.Classification c = PS_TicketService.classify('Need VPN access, my laptop login is locked');
        System.assertEquals('IT Access', c.category);
        System.assert(c.confidence > 0);
        System.assertEquals('Other', PS_TicketService.classify('').category);
        System.assertEquals(null, PS_TicketService.searchTerm('is it a'));
        System.assert(PS_TicketService.slaHours().containsKey('Critical'));
        System.assertEquals(3, PS_Util.splitSkills('Apex; LWC ,Java').size());
        System.assert(PS_Util.isHrUser());
        System.assertEquals(null, PS_Util.currentEmployee());
        try { PS_Util.requireCurrentEmployee(); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(true); }
        AuraHandledException ae = PS_Util.auraError(new PS_Util.PS_Exception('boom'));
        System.assertEquals('boom', ae.getMessage());
        PS_Util.notify(UserInfo.getUserId(), 'Hello', 'World', UserInfo.getUserId());
    }
}
