@IsTest
private class PS_TalentTest {

    @IsTest
    static void quizIsGradedServerSideAndIssuesCertificate() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Learning_Course__c c = PS_TestFactory.course('Security Basics', false, 12);
        insert c;
        Quiz_Question__c q1 = new Quiz_Question__c(Course__c = c.Id, Question__c = '2+2?', Option_A__c = '3', Option_B__c = '4', Correct_Option__c = 'B', Points__c = 1, Sequence__c = 1);
        Quiz_Question__c q2 = new Quiz_Question__c(Course__c = c.Id, Question__c = 'Sky?', Option_A__c = 'Blue', Option_B__c = 'Green', Correct_Option__c = 'A', Points__c = 1, Sequence__c = 2);
        insert new List<Quiz_Question__c>{ q1, q2 };
        Learning_Enrollment__c le = PS_LearningService.enroll(w.manager.Id, c.Id, 'Manual');

        Test.startTest();
        PS_LearningService.Quiz quiz = PS_LearningService.getQuiz(le.Id);
        System.assertEquals(2, quiz.questions.size());
        System.assertEquals('In Progress', [SELECT Status__c FROM Learning_Enrollment__c WHERE Id = :le.Id].Status__c);

        PS_LearningService.QuizResult fail = PS_LearningService.submitQuiz(le.Id, new Map<String, String>{ q1.Id => 'A', q2.Id => 'B' });
        System.assertEquals(false, fail.passed);
        System.assertEquals('Failed', [SELECT Status__c FROM Learning_Enrollment__c WHERE Id = :le.Id].Status__c);

        PS_LearningService.QuizResult pass = PS_LearningService.submitQuiz(le.Id, new Map<String, String>{ q1.Id => 'B', q2.Id => 'A' });
        System.assertEquals(100, pass.score);
        System.assert(pass.passed);
        System.assert(pass.certificateIssued);
        try { PS_LearningService.submitQuiz(le.Id, null); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(e.getMessage().contains('already')); }
        Test.stopTest();

        Learning_Enrollment__c done = [SELECT Status__c, Attempts__c, Completion_Date__c FROM Learning_Enrollment__c WHERE Id = :le.Id];
        System.assertEquals('Completed', done.Status__c);
        System.assertEquals(2, done.Attempts__c);
        Certification__c cert = [SELECT Expires_On__c, Status__c FROM Certification__c WHERE Employee__c = :w.manager.Id];
        System.assertEquals(Date.today().addMonths(12), cert.Expires_On__c);
    }

    @IsTest
    static void prerequisitesRecommendationsAndOverdue() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Learning_Course__c basics = PS_TestFactory.course('LWC Basics', false, null);
        insert basics;
        Learning_Course__c adv = PS_TestFactory.course('LWC Advanced', false, null);
        adv.Prerequisite_Course__c = basics.Id;
        insert adv;
        try { PS_LearningService.enroll(w.employee.Id, adv.Id, 'Manual'); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(e.getMessage().contains('prerequisite')); }

        // employee lacks "lwc" which the designation requires -> basics recommended
        List<PS_LearningService.Recommendation> recs = PS_LearningService.recommend(w.employee.Id, 5);
        System.assertEquals(1, recs.size());
        System.assertEquals(basics.Id, recs[0].courseId);

        Learning_Enrollment__c le = PS_LearningService.enroll(w.employee.Id, basics.Id, 'Manual');
        try { PS_LearningService.enroll(w.employee.Id, basics.Id, 'Manual'); System.assert(false); } catch (PS_Util.PS_Exception e) { System.assert(e.getMessage().contains('already')); }
        update new Learning_Enrollment__c(Id = le.Id, Status__c = 'Completed');
        System.assertNotEquals(null, PS_LearningService.enroll(w.employee.Id, adv.Id, 'Manual').Id);

        Learning_Enrollment__c late = PS_LearningService.newEnrollment(w.manager.Id, basics, 'Manual');
        late.Due_Date__c = Date.today().addDays(-1);
        insert late;
        System.assertEquals(1, PS_LearningService.markOverdue());
    }

    @IsTest
    static void reviewsUpdateEmployeeRating() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Performance_Review__c r = new Performance_Review__c(Employee__c = w.employee.Id, Reviewer__c = w.manager.Id, Review_Cycle__c = 'Annual', Status__c = 'Manager Review', Self_Rating__c = 4);
        insert r;
        System.assertEquals(String.valueOf(Date.today().year()), [SELECT Review_Year__c FROM Performance_Review__c WHERE Id = :r.Id].Review_Year__c);
        try { update new Performance_Review__c(Id = r.Id, Manager_Rating__c = 7); System.assert(false); } catch (DmlException e) { System.assert(true); }
        update new Performance_Review__c(Id = r.Id, Manager_Rating__c = 4.5, Status__c = 'Completed');
        System.assertEquals(4.5, [SELECT Performance_Rating__c FROM Employee__c WHERE Id = :w.employee.Id].Performance_Rating__c);
        System.assertEquals(4.5, [SELECT Final_Rating__c FROM Performance_Review__c WHERE Id = :r.Id].Final_Rating__c);
    }

    @IsTest
    static void hiringConvertsCandidateIntoPreboardingEmployee() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Job_Requisition__c req = new Job_Requisition__c(Name = 'Salesforce Developer', Department__c = w.eng.Id, Location__c = w.loc.Id,
            Designation__c = w.dev.Id, Hiring_Manager__c = w.manager.Id, Openings__c = 1, Required_Skills__c = 'Apex;LWC', Status__c = 'Draft');
        insert req;
        update new Job_Requisition__c(Id = req.Id, Status__c = 'Open');
        System.assertEquals(Date.today(), [SELECT Posted_On__c FROM Job_Requisition__c WHERE Id = :req.Id].Posted_On__c);

        Candidate__c cand = new Candidate__c(Name = 'Priya Sharma', Email__c = 'priya@example.com', Job_Requisition__c = req.Id,
            Skills__c = 'Apex;Java', Experience_Years__c = 4, Current_Company__c = 'Acme', Offered_CTC__c = 1400000,
            Resume_Text__c = 'Salesforce developer with 4 years building Apex services. Led migration to LWC. Loves testing.');
        insert cand;
        cand = [SELECT Match_Score__c, Resume_Summary__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals(50, cand.Match_Score__c);
        System.assert(cand.Resume_Summary__c.contains('apex'), cand.Resume_Summary__c);

        insert new List<Interview__c>{
            new Interview__c(Candidate__c = cand.Id, Round__c = 'Technical 1', Status__c = 'Completed', Rating__c = 4),
            new Interview__c(Candidate__c = cand.Id, Round__c = 'HR', Status__c = 'Completed', Rating__c = 5)
        };
        System.assertEquals(4.5, [SELECT Overall_Rating__c FROM Candidate__c WHERE Id = :cand.Id].Overall_Rating__c);

        Test.startTest();
        update new Candidate__c(Id = cand.Id, Stage__c = 'Offer');
        System.assertEquals('Released', [SELECT Offer_Status__c FROM Candidate__c WHERE Id = :cand.Id].Offer_Status__c);
        update new Candidate__c(Id = cand.Id, Stage__c = 'Hired');
        Test.stopTest();

        cand = [SELECT Converted_Employee__c, Offer_Status__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertNotEquals(null, cand.Converted_Employee__c);
        Employee__c hire = [SELECT Status__c, Manager__c, Annual_CTC__c FROM Employee__c WHERE Id = :cand.Converted_Employee__c];
        System.assertEquals('Pre-boarding', hire.Status__c);
        System.assertEquals(w.manager.Id, hire.Manager__c);
        System.assertEquals(1, [SELECT COUNT() FROM Onboarding__c WHERE Employee__c = :hire.Id]);
        System.assertEquals('Filled', [SELECT Status__c FROM Job_Requisition__c WHERE Id = :req.Id].Status__c);
    }

    @IsTest
    static void internalMobilityMovesExistingEmployee() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Job_Requisition__c req = new Job_Requisition__c(Name = 'HR Partner', Department__c = w.hr.Id, Designation__c = w.lead.Id, Openings__c = 2, Status__c = 'Open', Internal_Posting__c = true);
        insert req;
        try { insert new Candidate__c(Name = 'X', Job_Requisition__c = req.Id, Source__c = 'Internal'); System.assert(false); } catch (DmlException e) { System.assert(true); }
        Candidate__c c = new Candidate__c(Name = 'Eli Engineer', Job_Requisition__c = req.Id, Source__c = 'Internal', Internal_Employee__c = w.employee.Id);
        insert c;
        update new Candidate__c(Id = c.Id, Stage__c = 'Hired');
        Employee__c e = [SELECT Department__c, Designation__c FROM Employee__c WHERE Id = :w.employee.Id];
        System.assertEquals(w.hr.Id, e.Department__c);
        System.assertEquals(w.lead.Id, e.Designation__c);
        System.assertEquals(1, [SELECT Filled__c FROM Job_Requisition__c WHERE Id = :req.Id].Filled__c);
    }

    @IsTest
    static void compensationRevisionNeedsApprovalBeforeApplying() {
        PS_TestFactory.World w = PS_TestFactory.world();
        Compensation_Revision__c cr = new Compensation_Revision__c(Employee__c = w.employee.Id, New_CTC__c = 1320000);
        insert cr;
        System.assertEquals(1200000, [SELECT Previous_CTC__c FROM Compensation_Revision__c WHERE Id = :cr.Id].Previous_CTC__c);
        try { update new Compensation_Revision__c(Id = cr.Id, Status__c = 'Applied'); System.assert(false); } catch (DmlException e) { System.assert(e.getMessage().contains('approved')); }
        update new Compensation_Revision__c(Id = cr.Id, Status__c = 'Approved');
        update new Compensation_Revision__c(Id = cr.Id, Status__c = 'Applied');
        System.assertEquals(1320000, [SELECT Annual_CTC__c FROM Employee__c WHERE Id = :w.employee.Id].Annual_CTC__c);
    }

    @IsTest
    static void recognitionSurveysAndPolicies() {
        PS_TestFactory.World w = PS_TestFactory.world();
        insert new Recognition__c(Giver__c = w.manager.Id, Recipient__c = w.employee.Id, Badge__c = 'Innovator', Points__c = 25);
        System.assertEquals(25, [SELECT Recognition_Points__c FROM Employee__c WHERE Id = :w.employee.Id].Recognition_Points__c);
        try { insert new Recognition__c(Giver__c = w.employee.Id, Recipient__c = w.employee.Id); System.assert(false); } catch (DmlException e) { System.assert(true); }

        Pulse_Survey__c s = new Pulse_Survey__c(Name = 'eNPS', Question__c = 'Recommend us?', Survey_Type__c = 'eNPS', Anonymous__c = true, Active__c = true);
        insert s;
        Survey_Response__c r = new Survey_Response__c(Pulse_Survey__c = s.Id, Score__c = 9, Employee__c = w.manager.Id);
        insert r;
        r = [SELECT Sentiment__c, Employee__c, Department__c, Respondent_Key__c FROM Survey_Response__c WHERE Id = :r.Id];
        System.assertEquals('Positive', r.Sentiment__c);
        System.assertEquals(null, r.Employee__c);
        System.assertEquals(w.eng.Id, r.Department__c);
        try { insert new Survey_Response__c(Pulse_Survey__c = s.Id, Score__c = 3); System.assert(false); } catch (DmlException e) { System.assert(true); }

        HR_Policy__c p = new HR_Policy__c(Name = 'Employee Handbook', Category__c = 'Code of Conduct', Version__c = '2', Requires_Acknowledgement__c = true, Active__c = true);
        insert p;
        insert new Policy_Acknowledgement__c(HR_Policy__c = p.Id, Employee__c = w.employee.Id);
        System.assert([SELECT Handbook_Acknowledged__c FROM Employee__c WHERE Id = :w.employee.Id].Handbook_Acknowledged__c);
        System.assertEquals('2', [SELECT Version__c FROM Policy_Acknowledgement__c WHERE Employee__c = :w.employee.Id].Version__c);
    }
}
