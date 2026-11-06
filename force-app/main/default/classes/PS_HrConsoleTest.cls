@IsTest
private class PS_HrConsoleTest {

    @TestSetup
    static void setup() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Job_Requisition__c req = new Job_Requisition__c(Name = 'Engineer', Department__c = w.eng.Id, Designation__c = w.dev.Id,
            Hiring_Manager__c = w.manager.Id, Openings__c = 1, Status__c = 'Open', Required_Skills__c = 'Apex');
        insert req;
        insert new Candidate__c(Name = 'Casey Candidate', Job_Requisition__c = req.Id, Skills__c = 'Apex', Stage__c = 'Interview');
        insert new Candidate__c(Name = 'Robin Rejected', Job_Requisition__c = req.Id, Stage__c = 'Rejected');
        insert new HR_Ticket__c(Employee__c = w.employee.Id, Subject__c = 'Payslip', Description__c = 'Where is my payslip?');
        Employee__c nj = PS_TestFactory.employee(w, 'Nora', 'New', 'Pre-boarding', w.manager.Id);
        insert nj;
        Date mon = PS_TestFactory.nextMonday();
        insert new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = mon, End_Date__c = mon);
        insert new Expense_Claim__c(Employee__c = w.employee.Id, Category__c = 'Food', Amount__c = 50, Expense_Date__c = Date.today());
        insert new Performance_Review__c(Employee__c = w.employee.Id, Status__c = 'Manager Review', Self_Rating__c = 4);
    }

    @IsTest
    static void serviceDeskFlow() {
        Map<String, Object> res = PS_HrOpsController.getTickets('open');
        List<HR_Ticket__c> tickets = (List<HR_Ticket__c>) res.get('tickets');
        System.assertEquals(1, tickets.size());
        for (String v : new List<String>{ 'breached', 'mine', 'closed', 'all' }) System.assertNotEquals(null, PS_HrOpsController.getTickets(v));
        PS_HrOpsController.updateTicket(tickets[0].Id, 'Resolved', 'Low', 'Payslips are in the payroll portal.');
        System.assertEquals('Resolved', [SELECT Status__c FROM HR_Ticket__c WHERE Id = :tickets[0].Id].Status__c);
        System.assertEquals(0, PS_HrOpsController.runEscalation());
        try { PS_HrOpsController.updateTicket(tickets[0].Id, 'Bogus', null, null); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
    }

    @IsTest
    static void recruitmentPipelineHiresIntoOnboarding() {
        Map<String, Object> p = PS_HrOpsController.getPipeline();
        List<Object> reqs = (List<Object>) p.get('requisitions');
        System.assertEquals(1, reqs.size());
        System.assertEquals(1, ((Map<String, Object>) reqs[0]).get('rejected'));
        Candidate__c c = [SELECT Id FROM Candidate__c WHERE Name = 'Casey Candidate'];
        Test.startTest();
        Map<String, Object> hired = PS_HrOpsController.moveCandidate(c.Id, 'Hired');
        Test.stopTest();
        Id empId = (Id) hired.get('employeeId');
        System.assertNotEquals(null, empId);
        System.assertEquals(1, [SELECT COUNT() FROM Onboarding__c WHERE Employee__c = :empId]);
        PS_HrOpsController.setRequisitionStatus(((Id) ((Map<String, Object>) reqs[0]).get('id')), 'On Hold');
        PS_HrOpsController.moveCandidate([SELECT Id FROM Candidate__c WHERE Name = 'Robin Rejected'].Id, 'Rejected');
    }

    @IsTest
    static void explorerAndOnboardings() {
        List<Map<String, Object>> objs = PS_DataExplorerController.getObjects();
        System.assertEquals(PS_DataExplorerController.OBJECTS.size(), objs.size());
        Test.startTest();
        for (String api : PS_DataExplorerController.OBJECTS) {
            Map<String, Object> r = PS_DataExplorerController.getRecords(api, null);
            System.assert(((List<Object>) r.get('columns')).size() >= 1, api);
        }
        System.assert(((List<Object>) PS_DataExplorerController.getRecords('Employee__c', 'Nora').get('rows')).size() == 1);
        try { PS_DataExplorerController.getRecords('Account', null); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        Test.stopTest();
        System.assert(PS_HrOpsController.getOpenOnboardings().size() >= 1);
    }

    static String tok() { return PS_GuestHrGateway.unlock('admin123'); }

    @IsTest
    static void passwordIsEnforcedOnTheServer() {
        try { PS_GuestHrGateway.unlock('wrong'); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        try { PS_GuestHrGateway.unlock(null); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        String t = tok();
        System.assert(PS_GuestHrGateway.checkToken(t));
        System.assert(!PS_GuestHrGateway.checkToken(null));
        System.assert(!PS_GuestHrGateway.checkToken('123.abc'));
        System.assert(!PS_GuestHrGateway.checkToken('notanumber.abc'));
        String expired = String.valueOf(System.currentTimeMillis() - 1000) + '.' + t.substringAfter('.');
        System.assert(!PS_GuestHrGateway.checkToken(expired));
        String forged = String.valueOf(System.currentTimeMillis() + 99999999L) + '.' + t.substringAfter('.');
        System.assert(!PS_GuestHrGateway.checkToken(forged));
        try { PS_GuestHrGateway.getOverview(null); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        try { PS_GuestHrGateway.getOverview(forged); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
    }

    @IsTest
    static void hrGatewayCoversEveryFeature() {
        String t = tok();
        Test.startTest();
        System.assertNotEquals(null, PS_GuestHrGateway.getOverview(t));
        System.assert(PS_GuestHrGateway.searchEmployees('Eli', t).size() >= 1);
        Employee__c eli = [SELECT Id FROM Employee__c WHERE Name = 'Eli Engineer'];
        Map<String, Object> e360 = PS_GuestHrGateway.getEmployee360(eli.Id, t);
        System.assertNotEquals(null, ((Map<String, Object>) e360.get('employee')).get('ctc'));
        System.assertNotEquals(null, PS_GuestHrGateway.getEmployee360(null, t));
        System.assertNotEquals(null, PS_GuestHrGateway.getOrgTree(null, t));
        List<Map<String, Object>> onbs = PS_GuestHrGateway.getOpenOnboardings(t);
        Map<String, Object> onb = PS_GuestHrGateway.getOnboarding((Id) onbs[0].get('id'), t);
        Onboarding_Task__c task = [SELECT Id FROM Onboarding_Task__c LIMIT 1];
        PS_GuestHrGateway.setTaskStatus(task.Id, 'Completed', t);
        PS_GuestHrGateway.updateTaskStatus(task.Id, 'In Progress', t);
        Employee_Document__c d = [SELECT Id FROM Employee_Document__c LIMIT 1];
        PS_GuestHrGateway.verifyDocument(d.Id, false, 'Blurry', t);
        Test.stopTest();
    }

    @IsTest
    static void hrGatewayApprovalsDeskAndHiring() {
        String t = tok();
        Employee__c eli = [SELECT Id FROM Employee__c WHERE Name = 'Eli Engineer'];
        Test.startTest();
        Map<String, Object> hr = PS_GuestHrGateway.getHrOverview(t);
        System.assertEquals(true, hr.get('orgWide'));
        List<Leave_Request__c> leaves = (List<Leave_Request__c>) hr.get('leaveApprovals');
        PS_GuestHrGateway.decideLeave(leaves[0].Id, true, 'ok', t);
        PS_GuestHrGateway.decideExpense(((List<Expense_Claim__c>) hr.get('expenseApprovals'))[0].Id, false, 'no receipt', t);
        PS_GuestHrGateway.submitManagerReview([SELECT Id FROM Performance_Review__c LIMIT 1].Id, 4, 'Great', false, true, t);
        PS_GuestHrGateway.giveRecognition(eli.Id, 'Mentor', 'Thanks', t);
        Map<String, Object> tk = PS_GuestHrGateway.getTickets('open', t);
        PS_GuestHrGateway.updateTicket(((List<HR_Ticket__c>) tk.get('tickets'))[0].Id, 'In Progress', null, null, t);
        PS_GuestHrGateway.runEscalation(t);
        Map<String, Object> pipe = PS_GuestHrGateway.getPipeline(t);
        PS_GuestHrGateway.moveCandidate([SELECT Id FROM Candidate__c WHERE Name = 'Casey Candidate'].Id, 'Offer', t);
        PS_GuestHrGateway.setRequisitionStatus([SELECT Id FROM Job_Requisition__c LIMIT 1].Id, 'Open', t);
        Test.stopTest();
        System.assertEquals('Completed', [SELECT Status__c FROM Performance_Review__c LIMIT 1].Status__c);
    }

    @IsTest
    static void hrGatewayExplorerAndAssistant() {
        String t = tok();
        Test.startTest();
        System.assert(!PS_GuestHrGateway.getObjects(t).isEmpty());
        System.assertNotEquals(null, PS_GuestHrGateway.getRecords('HR_Ticket__c', null, t));
        System.assertEquals('risk', PS_GuestHrGateway.ask('Who is high risk?', t).intent);
        System.assert(!PS_GuestHrGateway.suggestions(t).isEmpty());
        Test.stopTest();
    }

    @IsTest
    static void managerHrOverviewForInternalHr() {
        Map<String, Object> o = PS_ManagerController.getHrOverview();
        System.assertEquals(true, o.get('orgWide'));
        System.assertNotEquals(null, PS_ManagerController.largestTeamManager());
    }
}
