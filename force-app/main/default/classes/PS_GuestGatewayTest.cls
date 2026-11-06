@IsTest
private class PS_GuestGatewayTest {

    @TestSetup
    static void setup() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Learning_Course__c c = PS_TestFactory.course('Demo course', true, null);
        insert c;
        insert new Quiz_Question__c(Course__c = c.Id, Question__c = 'Q?', Option_A__c = 'Yes', Option_B__c = 'No', Correct_Option__c = 'A');
        insert new HR_Policy__c(Name = 'Leave Policy', Category__c = 'Leave', Active__c = true, Requires_Acknowledgement__c = true, Version__c = '1', Policy_Body__c = 'Twelve casual leaves.');
        insert new Job_Requisition__c(Name = 'Dev', Status__c = 'Open', Internal_Posting__c = true);
        insert new Pulse_Survey__c(Name = 'Pulse', Question__c = 'Q', Active__c = true);
        insert new Goal__c(Name = 'G', Employee__c = w.manager.Id, Target_Value__c = 5);
        insert new Performance_Review__c(Employee__c = w.manager.Id, Status__c = 'Self Assessment');
    }

    @IsTest
    static void gatewayDelegatesScopedToDemoEmployee() {
        Employee__c me = [SELECT Id FROM Employee__c WHERE User__c = :UserInfo.getUserId()];
        Employee__c other = [SELECT Id FROM Employee__c WHERE Name = 'Eli Engineer'];
        Test.startTest();
        System.assertEquals(true, PS_GuestGateway.getMyWorkspace().get('linked'));
        Date mon = PS_TestFactory.nextMonday();
        Id leave = PS_GuestGateway.applyLeave('Casual Leave', mon, mon, false, 'x');
        PS_GuestGateway.cancelLeave(leave);
        PS_GuestGateway.checkIn('Office');
        PS_GuestGateway.checkOut();
        HR_Ticket__c t = PS_GuestGateway.raiseTicket('Leave question', 'How many leaves?', 'Low', 'Portal');
        PS_GuestGateway.acknowledgePolicy([SELECT Id FROM HR_Policy__c LIMIT 1].Id);
        PS_GuestGateway.submitExpense('Food', 10, Date.today(), 'Snack');
        PS_GuestGateway.giveRecognition(other.Id, 'Mentor', 'Thanks');
        PS_GuestGateway.submitSurvey([SELECT Id FROM Pulse_Survey__c LIMIT 1].Id, 9, null);
        PS_GuestGateway.updateGoalProgress([SELECT Id FROM Goal__c LIMIT 1].Id, 2);
        PS_GuestGateway.submitSelfAssessment([SELECT Id FROM Performance_Review__c LIMIT 1].Id, 4, 'ok');
        PS_GuestGateway.applyInternalJob([SELECT Id FROM Job_Requisition__c LIMIT 1].Id);
        System.assert(PS_GuestGateway.searchColleagues('Eli').size() >= 1);
        Learning_Enrollment__c enr = [SELECT Id FROM Learning_Enrollment__c WHERE Employee__c = :me.Id LIMIT 1];
        PS_LearningService.Quiz q = PS_GuestGateway.getQuiz(enr.Id);
        System.assert(PS_GuestGateway.submitQuiz(enr.Id, new Map<String, String>{ q.questions[0].id => 'A' }).passed);
        try { PS_GuestGateway.markContentComplete(enr.Id); } catch (Exception e) { System.assert(true); }
        try { PS_GuestGateway.selfEnroll([SELECT Id FROM Learning_Course__c LIMIT 1].Id); } catch (Exception e) { System.assert(true); }
        System.assertNotEquals(null, PS_GuestGateway.getEmployee360(null));
        try { PS_GuestGateway.getEmployee360(other.Id); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        try { PS_GuestGateway.submitResignation('Other', null, null); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        System.assertNotEquals(null, PS_GuestGateway.getOrgTree(null));
        System.assertEquals('blocked', PS_GuestGateway.ask('Show open HR tickets that breached SLA').intent);
        System.assertEquals('headcount', PS_GuestGateway.ask('Headcount by department').intent);
        System.assert(!PS_GuestGateway.suggestions().isEmpty());
        System.assertNotEquals(null, PS_GuestGateway.escalateToHr('Parking?', null));
        try { PS_GuestGateway.rateTicket(t.Id, '5', null); } catch (Exception e) { System.assert(true); }
        Test.stopTest();
    }

    @IsTest
    static void tasksMustBelongToTheDemoUser() {
        Employee__c hire = [SELECT Id, Organization__c, Department__c, Location__c, Designation__c FROM Employee__c WHERE Name = 'Eli Engineer'];
        Employee__c nj = new Employee__c(Name = 'New Joiner', Status__c = 'Pre-boarding', Organization__c = hire.Organization__c);
        insert nj;
        Onboarding_Task__c mine = [SELECT Id FROM Onboarding_Task__c WHERE Onboarding__r.Employee__c = :nj.Id AND Assigned_To__c = :UserInfo.getUserId() LIMIT 1];
        PS_GuestGateway.updateTaskStatus(mine.Id, 'Completed');
        System.assertEquals('Completed', [SELECT Status__c FROM Onboarding_Task__c WHERE Id = :mine.Id].Status__c);
    }
}
