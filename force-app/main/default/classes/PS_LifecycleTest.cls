@IsTest
private class PS_LifecycleTest {

    @IsTest
    static void newHireGetsIdOnboardingDocumentsAndMandatoryLearning() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Learning_Course__c c = PS_TestFactory.course('Code of Conduct', true, 12);
        insert c;
        Test.startTest();
        Employee__c hire = PS_TestFactory.employee(w, 'Nia', 'New', 'Pre-boarding', w.manager.Id);
        hire.Date_of_Joining__c = Date.today();
        insert hire;
        Test.stopTest();

        hire = [SELECT Employee_ID__c, Profile_Completeness__c FROM Employee__c WHERE Id = :hire.Id];
        System.assert(hire.Employee_ID__c.startsWith('TST-'), hire.Employee_ID__c);
        System.assert(hire.Profile_Completeness__c > 0);
        Onboarding__c onb = [SELECT Id, Status__c, (SELECT Id FROM Tasks__r) FROM Onboarding__c WHERE Employee__c = :hire.Id];
        System.assertEquals(PS_OnboardingService.DEFAULT_TASKS.size(), onb.Tasks__r.size());
        System.assertEquals(PS_OnboardingService.REQUIRED_DOCUMENTS.size(), [SELECT COUNT() FROM Employee_Document__c WHERE Employee__c = :hire.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Learning_Enrollment__c WHERE Employee__c = :hire.Id AND Course__c = :c.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Employment_History__c WHERE Employee__c = :hire.Id AND Event_Type__c = 'Joined']);
        // existing employees also got the mandatory course when it was created
        System.assertEquals(1, [SELECT COUNT() FROM Learning_Enrollment__c WHERE Employee__c = :w.employee.Id AND Course__c = :c.Id]);
    }

    @IsTest
    static void templateDrivesTasksAndCompletionActivatesEmployee() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Checklist_Template__c tpl = new Checklist_Template__c(Name = 'Engineering onboarding', Process_Type__c = 'Onboarding', Department__c = w.eng.Id, Active__c = true, Duration_Days__c = 14);
        insert tpl;
        insert new List<Checklist_Template_Item__c>{
            new Checklist_Template_Item__c(Name = 'Laptop', Checklist_Template__c = tpl.Id, Assigned_Team__c = 'IT', Days_Offset__c = 0, Mandatory__c = true, Sequence__c = 1),
            new Checklist_Template_Item__c(Name = 'Meet team', Checklist_Template__c = tpl.Id, Assigned_Team__c = 'Manager', Days_Offset__c = 1, Mandatory__c = true, Sequence__c = 2),
            new Checklist_Template_Item__c(Name = 'Optional lunch', Checklist_Template__c = tpl.Id, Assigned_Team__c = 'HR', Days_Offset__c = 2, Mandatory__c = false, Sequence__c = 3)
        };
        Employee__c hire = PS_TestFactory.employee(w, 'Tom', 'Template', 'Pre-boarding', w.manager.Id);
        insert hire;
        Onboarding__c onb = [SELECT Id, Checklist_Template__c, (SELECT Id, Mandatory__c, Assigned_To__c, Assigned_Team__c FROM Tasks__r) FROM Onboarding__c WHERE Employee__c = :hire.Id];
        System.assertEquals(tpl.Id, onb.Checklist_Template__c);
        System.assertEquals(3, onb.Tasks__r.size());

        Test.startTest();
        List<Onboarding_Task__c> mandatory = new List<Onboarding_Task__c>();
        for (Onboarding_Task__c t : onb.Tasks__r) {
            if (t.Assigned_Team__c == 'Manager') System.assertEquals(UserInfo.getUserId(), t.Assigned_To__c);
            if (t.Mandatory__c) mandatory.add(new Onboarding_Task__c(Id = t.Id, Status__c = 'In Progress'));
        }
        update mandatory;
        System.assertEquals('Onboarding', [SELECT Status__c FROM Employee__c WHERE Id = :hire.Id].Status__c);
        for (Onboarding_Task__c t : mandatory) t.Status__c = 'Completed';
        update mandatory;
        Test.stopTest();

        System.assertEquals('Completed', [SELECT Status__c FROM Onboarding__c WHERE Id = :onb.Id].Status__c);
        System.assertEquals('Active', [SELECT Status__c FROM Employee__c WHERE Id = :hire.Id].Status__c);
        System.assertNotEquals(null, [SELECT Completed_On__c FROM Onboarding_Task__c WHERE Id = :mandatory[0].Id].Completed_On__c);
    }

    @IsTest
    static void changesAreRecordedAsHistory() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Test.startTest();
        update new Employee__c(Id = w.employee.Id, Department__c = w.hr.Id, Designation__c = w.lead.Id, Annual_CTC__c = 1500000);
        Test.stopTest();
        Set<String> types = new Set<String>();
        for (Employment_History__c h : [SELECT Event_Type__c FROM Employment_History__c WHERE Employee__c = :w.employee.Id]) types.add(h.Event_Type__c);
        System.assert(types.contains('Transfer'), types);
        System.assert(types.contains('Promotion'), types);
        System.assert(types.contains('Compensation Change'), types);
    }

    @IsTest
    static void duplicateWorkEmailIsBlocked() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Employee__c dup = PS_TestFactory.employee(w, 'Dee', 'Dup', 'Active', null);
        dup.Work_Email__c = [SELECT Work_Email__c FROM Employee__c WHERE Id = :w.employee.Id].Work_Email__c;
        try {
            insert dup;
            System.assert(false, 'expected duplicate email error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('already used'), e.getMessage());
        }
    }

    @IsTest
    static void offboardingCoordinatesClearanceAndAssets() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Company_Asset__c laptop = new Company_Asset__c(Name = 'MacBook', Asset_Tag__c = 'LT-1', Asset_Type__c = 'Laptop', Assigned_To__c = w.employee.Id);
        insert laptop;
        System.assertEquals('Assigned', [SELECT Status__c FROM Company_Asset__c WHERE Id = :laptop.Id].Status__c);
        insert new Expense_Claim__c(Employee__c = w.employee.Id, Category__c = 'Travel', Amount__c = 500, Expense_Date__c = Date.today(), Status__c = 'Submitted');

        Test.startTest();
        Exit_Process__c x = new Exit_Process__c(Employee__c = w.employee.Id, Exit_Reason__c = 'Career Growth');
        insert x;
        x = [SELECT Id, Last_Working_Day__c, Pending_Assets__c, Pending_Expenses__c, Status__c FROM Exit_Process__c WHERE Id = :x.Id];
        System.assertEquals(Date.today().addDays(30), x.Last_Working_Day__c);
        System.assertEquals(1, x.Pending_Assets__c);
        System.assertEquals(500, x.Pending_Expenses__c);
        System.assertEquals('On Notice', [SELECT Status__c FROM Employee__c WHERE Id = :w.employee.Id].Status__c);

        // second open exit is blocked
        try { insert new Exit_Process__c(Employee__c = w.employee.Id); System.assert(false); } catch (DmlException e) { System.assert(e.getMessage().contains('open exit')); }

        // returning the laptop completes its clearance task
        update new Company_Asset__c(Id = laptop.Id, Assigned_To__c = null);
        System.assertEquals('Completed', [SELECT Status__c FROM Exit_Task__c WHERE Exit_Process__c = :x.Id AND Name LIKE 'Return%'].Status__c);
        System.assertEquals('In Stock', [SELECT Status__c FROM Company_Asset__c WHERE Id = :laptop.Id].Status__c);

        // cannot complete with open mandatory tasks
        try { update new Exit_Process__c(Id = x.Id, Status__c = 'Completed'); System.assert(false); } catch (DmlException e) { System.assert(e.getMessage().contains('clearance')); }

        List<Exit_Task__c> tasks = [SELECT Id FROM Exit_Task__c WHERE Exit_Process__c = :x.Id AND Status__c != 'Completed'];
        for (Exit_Task__c t : tasks) t.Status__c = 'Completed';
        update tasks;
        System.assertEquals('Ready for Settlement', [SELECT Status__c FROM Exit_Process__c WHERE Id = :x.Id].Status__c);
        update new Exit_Process__c(Id = x.Id, Status__c = 'Completed', Rehire_Eligible__c = false);
        Test.stopTest();

        Employee__c e = [SELECT Status__c, Exit_Date__c, Rehire_Eligible__c FROM Employee__c WHERE Id = :w.employee.Id];
        System.assertEquals('Exited', e.Status__c);
        System.assertEquals(x.Last_Working_Day__c, e.Exit_Date__c);
        System.assertEquals(false, e.Rehire_Eligible__c);
    }

    @IsTest
    static void withdrawnResignationReactivatesEmployee() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Checklist_Template__c tpl = new Checklist_Template__c(Name = 'Exit', Process_Type__c = 'Offboarding', Active__c = true);
        insert tpl;
        insert new Checklist_Template_Item__c(Name = 'Handover', Checklist_Template__c = tpl.Id, Assigned_Team__c = 'Manager', Mandatory__c = true);
        Exit_Process__c x = new Exit_Process__c(Employee__c = w.employee.Id, Notice_Period_Days__c = 10);
        insert x;
        System.assertEquals(1, [SELECT COUNT() FROM Exit_Task__c WHERE Exit_Process__c = :x.Id]);
        update new Exit_Process__c(Id = x.Id, Status__c = 'Withdrawn');
        System.assertEquals('Active', [SELECT Status__c FROM Employee__c WHERE Id = :w.employee.Id].Status__c);
    }
}
