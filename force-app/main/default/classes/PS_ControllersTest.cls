@IsTest
private class PS_ControllersTest {

    @TestSetup
    static void setup() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Learning_Course__c c = PS_TestFactory.course('Compliance 101', true, 12);
        insert c;
        insert new Quiz_Question__c(Course__c = c.Id, Question__c = 'Q?', Option_A__c = 'Yes', Option_B__c = 'No', Correct_Option__c = 'A');
        insert new Learning_Course__c(Name = 'Reading course', Course_Code__c = 'READ-1', Category__c = 'Technical', Active__c = true, Skills_Covered__c = 'lwc');
        insert new HR_Policy__c(Name = 'Remote Work Policy', Category__c = 'Remote Work', Active__c = true, Requires_Acknowledgement__c = true, Version__c = '1',
            Summary__c = 'Rules for working from home.', Policy_Body__c = 'Employees may work from home two days per week. Manager approval is required.');
        insert new Pulse_Survey__c(Name = 'Pulse', Question__c = 'How are you?', Survey_Type__c = 'eNPS', Active__c = true, Anonymous__c = true);
        insert new Announcement__c(Name = 'Town hall', Body__c = 'Friday', Publish_Date__c = Date.today(), Pinned__c = true);
        insert new Holiday__c(Name = 'New Year', Holiday_Date__c = Date.today().addDays(40));
        insert new Goal__c(Name = 'Ship v2', Employee__c = w.manager.Id, Target_Value__c = 10, Current_Value__c = 0);
        insert new Performance_Review__c(Employee__c = w.manager.Id, Review_Cycle__c = 'Q1', Status__c = 'Self Assessment', Due_Date__c = Date.today().addDays(-1));
        insert new Performance_Review__c(Employee__c = w.employee.Id, Review_Cycle__c = 'Q1', Status__c = 'Manager Review', Self_Rating__c = 4);
        insert new Job_Requisition__c(Name = 'Platform Engineer', Department__c = w.eng.Id, Status__c = 'Open', Internal_Posting__c = true, Required_Skills__c = 'security');
        insert new Company_Asset__c(Name = 'Spare laptop', Asset_Tag__c = 'LT-9', Asset_Type__c = 'Laptop');
        insert new Recognition__c(Giver__c = w.employee.Id, Recipient__c = w.manager.Id, Badge__c = 'Mentor', Message__c = 'Thanks!');
        Employee__c hire = PS_TestFactory.employee(w, 'Olu', 'Onboard', 'Pre-boarding', w.manager.Id);
        hire.Date_of_Joining__c = Date.today().addDays(-10);
        insert hire;
        Date mon = PS_TestFactory.nextMonday();
        insert new Leave_Request__c(Employee__c = w.employee.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = mon, End_Date__c = mon);
        insert new Expense_Claim__c(Employee__c = w.employee.Id, Category__c = 'Travel', Amount__c = 99, Expense_Date__c = Date.today());
        insert new Certification__c(Name = 'AWS', Employee__c = w.employee.Id, Issued_On__c = Date.today().addYears(-1), Expires_On__c = Date.today().addDays(2));
    }

    static Employee__c me() { return [SELECT Id FROM Employee__c WHERE User__c = :UserInfo.getUserId() LIMIT 1]; }
    static Employee__c report() { return [SELECT Id FROM Employee__c WHERE Name = 'Eli Engineer' LIMIT 1]; }

    @IsTest
    static void dashboardOverview() {
        Map<String, Object> o = PS_DashboardController.getOverview();
        Map<String, Object> k = (Map<String, Object>) o.get('kpis');
        System.assert((Integer) k.get('activeHeadcount') >= 2);
        System.assertNotEquals(null, o.get('headcountByDepartment'));
        System.assertEquals(6, ((List<Object>) o.get('hiringTrend')).size());
        System.assertNotEquals(null, o.get('alerts'));
    }

    @IsTest
    static void employee360AndSearch() {
        Map<String, Object> d = PS_Employee360Controller.getEmployee360(report().Id);
        System.assertEquals(6, ((List<Object>) d.get('lifecycle')).size());
        System.assertNotEquals(null, d.get('timeline'));
        System.assertNotEquals(null, d.get('risks'));
        System.assertNotEquals(null, PS_Employee360Controller.getEmployee360(null));
        System.assert(PS_Employee360Controller.searchEmployees('Eli').size() >= 1);
        System.assertEquals(0, PS_Employee360Controller.searchEmployees('x').size());
        System.assert(PS_PortalController.searchColleagues('Maya').size() >= 1);
    }

    @IsTest
    static void portalWorkspaceAndActions() {
        Map<String, Object> ws = PS_PortalController.getMyWorkspace();
        System.assertEquals(true, ws.get('linked'));
        System.assertNotEquals(null, ws.get('activeSurvey'));
        System.assertEquals(1, ((List<Object>) ws.get('pendingPolicies')).size());

        Test.startTest();
        Date mon = PS_TestFactory.nextMonday().addDays(7);
        Id leaveId = PS_PortalController.applyLeave('Casual Leave', mon, mon, false, 'Personal');
        PS_PortalController.cancelLeave(leaveId);
        PS_PortalController.checkIn('Remote');
        PS_PortalController.checkOut();
        HR_Ticket__c t = PS_PortalController.raiseTicket('Leave balance question', 'How is leave calculated?', 'Low', null);
        System.assertEquals('Leave & Attendance', t.Category__c);
        update new HR_Ticket__c(Id = t.Id, Status__c = 'Resolved', Resolution__c = 'Explained');
        PS_PortalController.rateTicket(t.Id, '5', 'Great');
        HR_Policy__c pol = [SELECT Id FROM HR_Policy__c LIMIT 1];
        PS_PortalController.acknowledgePolicy(pol.Id);
        PS_PortalController.submitExpense('Food', 120, Date.today(), 'Lunch');
        PS_PortalController.giveRecognition(report().Id, 'Team Player', 'Nice work');
        PS_PortalController.submitSurvey([SELECT Id FROM Pulse_Survey__c LIMIT 1].Id, 8, 'Good');
        PS_PortalController.updateGoalProgress([SELECT Id FROM Goal__c LIMIT 1].Id, 10);
        Performance_Review__c r = [SELECT Id FROM Performance_Review__c WHERE Employee__c = :me().Id LIMIT 1];
        PS_PortalController.submitSelfAssessment(r.Id, 4, 'Solid year');
        PS_PortalController.applyInternalJob([SELECT Id FROM Job_Requisition__c LIMIT 1].Id);
        Onboarding_Task__c task = [SELECT Id FROM Onboarding_Task__c WHERE Assigned_To__c = :UserInfo.getUserId() LIMIT 1];
        PS_PortalController.updateTaskStatus(task.Id, 'Completed');
        Id exitId = PS_PortalController.submitResignation('Relocation', null, 'Moving cities');
        Test.stopTest();

        System.assertEquals('Closed', [SELECT Status__c FROM HR_Ticket__c WHERE Id = :t.Id].Status__c);
        System.assertEquals('Achieved', [SELECT Status__c FROM Goal__c LIMIT 1].Status__c);
        System.assertEquals('Manager Review', [SELECT Status__c FROM Performance_Review__c WHERE Id = :r.Id].Status__c);
        System.assertNotEquals(null, exitId);
        System.assertEquals(0, ((List<Object>) PS_PortalController.getMyWorkspace().get('pendingPolicies')).size());
        try { PS_PortalController.applyInternalJob([SELECT Id FROM Job_Requisition__c LIMIT 1].Id); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
    }

    @IsTest
    static void managerWorkspaceApprovals() {
        Map<String, Object> o = PS_ManagerController.getTeamOverview();
        System.assertEquals(true, o.get('linked'));
        System.assert(((List<Object>) o.get('team')).size() >= 1);
        List<Leave_Request__c> leaves = (List<Leave_Request__c>) o.get('leaveApprovals');
        List<Expense_Claim__c> claims = (List<Expense_Claim__c>) o.get('expenseApprovals');
        System.assertEquals(1, leaves.size());
        Test.startTest();
        PS_ManagerController.decideLeave(leaves[0].Id, true, 'ok');
        PS_ManagerController.decideExpense(claims[0].Id, true, 'ok');
        Performance_Review__c r = [SELECT Id FROM Performance_Review__c WHERE Employee__c = :report().Id LIMIT 1];
        PS_ManagerController.submitManagerReview(r.Id, 4, 'Great year', true, true);
        try { PS_ManagerController.decideLeave(leaves[0].Id, true, 'again'); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        Test.stopTest();
        System.assertEquals('Completed', [SELECT Status__c FROM Performance_Review__c WHERE Id = :r.Id].Status__c);
        System.assertEquals('Approved', [SELECT Status__c FROM Expense_Claim__c WHERE Id = :claims[0].Id].Status__c);
    }

    @IsTest
    static void assistantIntents() {
        List<String> questions = new List<String>{
            'What is my leave balance?', 'Show employees whose certifications expire this month', 'Show overdue mandatory training',
            'List employees whose performance reviews are overdue', 'Show onboarding processes pending for more than 3 days',
            'Which department has the highest attrition?', 'Who is on leave today?', 'Show open HR tickets that breached SLA',
            'Headcount by department', 'Any birthdays this month?', 'New joiners this month', 'Who is high risk?',
            'Laptops in stock', 'Open positions', 'help'
        };
        for (String q : questions) {
            PS_AssistantController.Answer a = PS_AssistantController.ask(q);
            System.assertNotEquals(null, a.text, q);
        }
        Employee__c e = report();
        Test.setFixedSearchResults(new List<Id>{ e.Id });
        PS_AssistantController.Answer skills = PS_AssistantController.ask('Who has Apex skills?');
        System.assertEquals('table', skills.mode);
        System.assertEquals(1, skills.rows.size());
        System.assertEquals(10, PS_AssistantController.suggestions().size());
        try { PS_AssistantController.ask(''); System.assert(false); } catch (AuraHandledException ex) { System.assert(true); }
    }

    @IsTest
    static void assistantPolicyFallbackAndEscalation() {
        HR_Policy__c p = [SELECT Id FROM HR_Policy__c LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ p.Id });
        PS_AssistantController.Answer a = PS_AssistantController.ask('Can I work from home?');
        System.assertEquals('policy', a.intent);
        System.assert(a.text.contains('Remote Work Policy'), a.text);
        System.assertEquals(1, a.sources.size());
        Test.setFixedSearchResults(new List<Id>());
        System.assert(PS_AssistantController.ask('Tell me about parking').text.contains('could not find'));
        HR_Ticket__c t = PS_AssistantController.escalateToHr('Parking rules?', 'Not found');
        System.assertEquals('AI Assistant', [SELECT Channel__c FROM HR_Ticket__c WHERE Id = :t.Id].Channel__c);
    }

    @IsTest
    static void orgChartLearningAndOnboarding() {
        Map<String, Object> tree = PS_OrgChartController.getOrgTree(null);
        System.assert((Integer) tree.get('total') >= 3);
        Department__c eng = [SELECT Id FROM Department__c WHERE Code__c = 'ENG'];
        System.assertNotEquals(null, PS_OrgChartController.getOrgTree(eng.Id));

        System.assert(PS_LearningController.getCatalog(null).size() >= 2);
        System.assert(PS_LearningController.getCatalog('Technical').size() >= 1);
        Id enr = PS_LearningController.selfEnroll([SELECT Id FROM Learning_Course__c WHERE Course_Code__c = 'READ-1'].Id);
        PS_LearningController.markContentComplete(enr);
        System.assertEquals('Completed', [SELECT Status__c FROM Learning_Enrollment__c WHERE Id = :enr].Status__c);
        System.assertNotEquals(null, PS_LearningController.getRecommendations());
        Learning_Enrollment__c quizEnr = [SELECT Id FROM Learning_Enrollment__c WHERE Employee__c = :me().Id AND Course__r.Name = 'Compliance 101' LIMIT 1];
        PS_LearningService.Quiz q = PS_LearningController.getQuiz(quizEnr.Id);
        try { PS_LearningController.markContentComplete(quizEnr.Id); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        PS_LearningService.QuizResult res = PS_LearningController.submitQuiz(quizEnr.Id, new Map<String, String>{ q.questions[0].id => 'A' });
        System.assert(res.passed);

        Employee__c hire = [SELECT Id FROM Employee__c WHERE Name = 'Olu Onboard'];
        Map<String, Object> onb = PS_OnboardingController.getOnboarding(hire.Id);
        System.assertNotEquals(null, onb);
        List<Object> teams = (List<Object>) onb.get('teams');
        System.assert(!teams.isEmpty());
        Onboarding_Task__c t = [SELECT Id FROM Onboarding_Task__c WHERE Onboarding__r.Employee__c = :hire.Id LIMIT 1];
        PS_OnboardingController.setTaskStatus(t.Id, 'Completed');
        Employee_Document__c d = [SELECT Id FROM Employee_Document__c WHERE Employee__c = :hire.Id LIMIT 1];
        PS_OnboardingController.verifyDocument(d.Id, true, null);
        System.assertEquals('Verified', [SELECT Verification_Status__c FROM Employee_Document__c WHERE Id = :d.Id].Verification_Status__c);
        System.assertEquals(null, PS_OnboardingController.getOnboarding(report().Id));
    }

    @IsTest
    static void dailyJob() {
        Employee__c e = report();
        update new Employee__c(Id = e.Id, Date_of_Birth__c = Date.today().addYears(-28), Performance_Rating__c = 2);
        insert new Employee_Document__c(Name = 'Visa', Employee__c = e.Id, Document_Type__c = 'Visa / Work Permit', Expiry_Date__c = Date.today().addDays(-1), Verification_Status__c = 'Verified');
        Test.startTest();
        Map<String, Integer> stats = PS_DailyJob.run();
        String jobId = PS_DailyJob.scheduleDaily();
        Test.stopTest();
        System.assertEquals(1, stats.get('expiredDocuments'));
        System.assert(stats.get('celebrations') >= 1);
        System.assertNotEquals(null, jobId);
        System.assertEquals('High', [SELECT Attrition_Risk__c FROM Employee__c WHERE Id = :e.Id].Attrition_Risk__c);
    }
}
