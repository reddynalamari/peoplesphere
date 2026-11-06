// PeopleSphere sample data - part 3: day-to-day operations.
String me = UserInfo.getName();
Map<String, Employee__c> e = new Map<String, Employee__c>();
for (Employee__c x : [SELECT Id, Name, Department__c, Location__c, Manager__c, Performance_Rating__c, Annual_CTC__c, Status__c, User__c
                      FROM Employee__c WHERE Organization__r.Name = 'Nimbus Technologies']) e.put(x.Name, x);
Map<String, Id> dept = new Map<String, Id>();
for (Department__c x : [SELECT Id, Code__c FROM Department__c]) dept.put(x.Code__c, x.Id);
Map<String, Id> loc = new Map<String, Id>();
for (Location__c x : [SELECT Id, City__c FROM Location__c]) loc.put(x.City__c, x.Id);
Map<String, Id> desig = new Map<String, Id>();
for (Designation__c x : [SELECT Id, Name FROM Designation__c]) desig.put(x.Name, x.Id);
List<String> myTeam = new List<String>{ 'Priya Sharma', 'Rahul Verma', 'Neha Gupta', 'Aditya Singh', 'Sneha Reddy', 'Karthik Subramanian' };

// ---------------- Assets ----------------------------------------------------
List<Company_Asset__c> assets = new List<Company_Asset__c>();
Integer n = 1;
for (Employee__c x : e.values()) {
    if (x.Status__c == 'Exited' || x.Status__c == 'Pre-boarding') continue;
    assets.add(new Company_Asset__c(Name = (Math.mod(n, 3) == 0 ? 'Dell Latitude 7440' : 'MacBook Pro 14"'), Asset_Tag__c = 'NIM-LT-' + String.valueOf(n).leftPad(4, '0'),
        Asset_Type__c = 'Laptop', Serial_Number__c = 'SN' + (100000 + n), Assigned_To__c = x.Id, Purchase_Date__c = Date.today().addDays(-400 + n),
        Purchase_Cost__c = Math.mod(n, 3) == 0 ? 115000 : 185000, Warranty_Expiry__c = Date.today().addDays(700), Condition__c = 'Good', Vendor__c = 'Apple Authorized Reseller', Location__c = x.Location__c));
    if (Math.mod(n, 4) == 0) assets.add(new Company_Asset__c(Name = 'Access Card', Asset_Tag__c = 'NIM-AC-' + String.valueOf(n).leftPad(4, '0'), Asset_Type__c = 'Access Card', Assigned_To__c = x.Id));
    n++;
}
for (Integer k = 0; k < 6; k++) {
    assets.add(new Company_Asset__c(Name = k < 4 ? 'MacBook Air 13"' : 'Dell 27" Monitor', Asset_Tag__c = 'NIM-STK-' + k, Asset_Type__c = k < 4 ? 'Laptop' : 'Monitor',
        Status__c = 'In Stock', Condition__c = 'New', Location__c = loc.get('Hyderabad'), Purchase_Cost__c = k < 4 ? 120000 : 28000, Purchase_Date__c = Date.today().addDays(-20)));
}
insert assets;

// ---------------- Attendance (last 10 working days) ------------------------
List<Attendance__c> att = new List<Attendance__c>();
List<String> people = new List<String>(myTeam);
people.add(me);
Integer seed = 7;
for (String nm : people) {
    Employee__c x = e.get(nm);
    Date day = Date.today().addDays(-1);
    Integer counted = 0;
    while (counted < 10) {
        if (!PS_Util.isWeekend(day)) {
            seed = Math.mod(seed * 31 + 11, 97);
            Integer inMin = 9 * 60 + 5 + Math.mod(seed, 50);
            Datetime cin = Datetime.newInstance(day, Time.newInstance(inMin / 60, Math.mod(inMin, 60), 0, 0));
            Boolean absent = Math.mod(seed, 23) == 0;
            att.add(new Attendance__c(Employee__c = x.Id, Attendance_Date__c = day, Status__c = absent ? 'Absent' : (Math.mod(seed, 5) == 0 ? 'Work From Home' : 'Present'),
                Check_In__c = absent ? null : cin, Check_Out__c = absent ? null : cin.addMinutes(8 * 60 + Math.mod(seed * 3, 120)),
                Work_Mode__c = Math.mod(seed, 5) == 0 ? 'Remote' : 'Office'));
            counted++;
        }
        day = day.addDays(-1);
    }
}
insert att;
// today: most of the team checked in
List<Attendance__c> today = new List<Attendance__c>();
for (String nm : new List<String>{ 'Priya Sharma', 'Neha Gupta', 'Sneha Reddy', 'Karthik Subramanian' }) {
    today.add(new Attendance__c(Employee__c = e.get(nm).Id, Attendance_Date__c = Date.today(), Status__c = 'Present', Work_Mode__c = 'Office',
        Check_In__c = Datetime.newInstance(Date.today(), Time.newInstance(9, nm == 'Karthik Subramanian' ? 58 : 20, 0, 0))));
}
insert today;

// ---------------- Leave ------------------------------------------------------
Date nextMon = Date.today().addDays(7);
while (PS_Util.isWeekend(nextMon) || Datetime.newInstance(nextMon, Time.newInstance(12, 0, 0, 0)).format('E') != 'Mon') nextMon = nextMon.addDays(1);
Date todayWork = Date.today();
while (PS_Util.isWeekend(todayWork)) todayWork = todayWork.addDays(1);
Leave_Request__c onLeave = new Leave_Request__c(Employee__c = e.get('Rahul Verma').Id, Leave_Type__c = 'Sick Leave', Start_Date__c = todayWork, End_Date__c = todayWork, Reason__c = 'Fever');
Leave_Request__c planned = new Leave_Request__c(Employee__c = e.get('Priya Sharma').Id, Leave_Type__c = 'Earned Leave', Start_Date__c = nextMon.addDays(14), End_Date__c = nextMon.addDays(18), Reason__c = 'Family trip to Kerala');
Leave_Request__c pend1 = new Leave_Request__c(Employee__c = e.get('Neha Gupta').Id, Leave_Type__c = 'Casual Leave', Start_Date__c = nextMon, End_Date__c = nextMon.addDays(1), Reason__c = 'Sister\'s wedding');
Leave_Request__c pend2 = new Leave_Request__c(Employee__c = e.get('Aditya Singh').Id, Leave_Type__c = 'Work From Home', Start_Date__c = nextMon.addDays(2), End_Date__c = nextMon.addDays(2), Reason__c = 'Internet installation at home');
Leave_Request__c other = new Leave_Request__c(Employee__c = e.get('Emily Carter').Id, Leave_Type__c = 'Casual Leave', Start_Date__c = nextMon.addDays(3), End_Date__c = nextMon.addDays(3));
insert new List<Leave_Request__c>{ onLeave, planned, pend1, pend2, other };
onLeave.Status__c = 'Approved';
planned.Status__c = 'Approved';
update new List<Leave_Request__c>{ onLeave, planned };

// ---------------- Expenses ---------------------------------------------------
insert new List<Expense_Claim__c>{
    new Expense_Claim__c(Employee__c = e.get('Priya Sharma').Id, Category__c = 'Travel', Amount__c = 8450, Expense_Date__c = Date.today().addDays(-6), Description__c = 'Client workshop in Bengaluru - flights', Receipt_Attached__c = true),
    new Expense_Claim__c(Employee__c = e.get('Karthik Subramanian').Id, Category__c = 'Internet & Phone', Amount__c = 1500, Expense_Date__c = Date.today().addDays(-3), Description__c = 'Monthly internet allowance', Receipt_Attached__c = true),
    new Expense_Claim__c(Employee__c = e.get('Emily Carter').Id, Category__c = 'Client Entertainment', Amount__c = 240, Expense_Date__c = Date.today().addDays(-9), Description__c = 'Dinner with Acme Corp', Status__c = 'Approved'),
    new Expense_Claim__c(Employee__c = e.get('Suresh Babu').Id, Category__c = 'Travel', Amount__c = 3200, Expense_Date__c = Date.today().addDays(-12), Description__c = 'Customer visit Mumbai')
};

// ---------------- HR tickets -------------------------------------------------
List<HR_Ticket__c> tickets = new List<HR_Ticket__c>{
    new HR_Ticket__c(Employee__c = e.get('Rahul Verma').Id, Subject__c = 'Salary not credited for this month', Description__c = 'My salary has not been credited yet. Please check urgently.'),
    new HR_Ticket__c(Employee__c = e.get('Neha Gupta').Id, Subject__c = 'Need address proof letter', Description__c = 'I need an employment letter for a bank account address proof.'),
    new HR_Ticket__c(Employee__c = e.get('Sneha Reddy').Id, Subject__c = 'VPN access not working', Description__c = 'Cannot login to VPN since the password reset, my access is locked.'),
    new HR_Ticket__c(Employee__c = e.get('Emily Carter').Id, Subject__c = 'Health insurance for spouse', Description__c = 'How do I add my spouse to the medical insurance benefit?'),
    new HR_Ticket__c(Employee__c = e.get('Ayesha Siddiqui').Id, Subject__c = 'Leave balance looks wrong', Description__c = 'My earned leave balance did not carry forward from last year.'),
    new HR_Ticket__c(Employee__c = e.get('Manoj Kumar').Id, Subject__c = 'Form 16 download', Description__c = 'Where can I download my Form 16 tax document?'),
    new HR_Ticket__c(Employee__c = e.get('Tanvi Agarwal').Id, Subject__c = 'Training certificate missing', Description__c = 'I completed the Figma course but the certificate is not visible.'),
    new HR_Ticket__c(Employee__c = e.get('Jason Lee').Id, Subject__c = 'Concern about team behaviour', Description__c = 'I want to raise a complaint about unfair treatment in my team.', Confidential__c = true)
};
insert tickets;
tickets[0].SLA_Due__c = System.now().addHours(-5);
tickets[4].SLA_Due__c = System.now().addHours(-30);
tickets[1].Status__c = 'Resolved';
tickets[1].Resolution__c = 'Employment letter issued and emailed.';
tickets[5].Status__c = 'Resolved';
tickets[5].Resolution__c = 'Form 16 is available under Documents in the payroll portal.';
tickets[6].Status__c = 'In Progress';
update tickets;
update new HR_Ticket__c(Id = tickets[1].Id, Satisfaction_Rating__c = '5', Status__c = 'Closed');

// ---------------- Performance: last year's annual reviews + current cycle -------
List<Performance_Review__c> reviews = new List<Performance_Review__c>();
String lastYear = String.valueOf(Date.today().year() - 1);
for (Employee__c x : e.values()) {
    if (x.Performance_Rating__c == null || x.Status__c == 'Exited') continue;
    reviews.add(new Performance_Review__c(Employee__c = x.Id, Reviewer__c = x.Manager__c, Review_Cycle__c = 'Annual', Review_Year__c = lastYear,
        Status__c = 'Completed', Self_Rating__c = Math.min(5, x.Performance_Rating__c + 0.5), Manager_Rating__c = x.Performance_Rating__c,
        Final_Rating__c = x.Performance_Rating__c, Due_Date__c = Date.newInstance(Date.today().year(), 1, 31), Completed_On__c = Date.newInstance(Date.today().year(), 2, 10),
        Manager_Feedback__c = 'Consistent delivery; focus next on cross-team influence.'));
}
String yr = String.valueOf(Date.today().year());
Id myEmp = e.get(me).Id;
reviews.add(new Performance_Review__c(Employee__c = e.get('Priya Sharma').Id, Reviewer__c = myEmp, Review_Cycle__c = 'Mid-Year', Review_Year__c = yr, Status__c = 'Manager Review', Self_Rating__c = 4.5, Due_Date__c = Date.today().addDays(10), Self_Assessment__c = 'Led the payments integration, mentored two engineers and cut deployment time by 40%.'));
reviews.add(new Performance_Review__c(Employee__c = e.get('Rahul Verma').Id, Reviewer__c = myEmp, Review_Cycle__c = 'Mid-Year', Review_Year__c = yr, Status__c = 'Self Assessment', Due_Date__c = Date.today().addDays(10)));
reviews.add(new Performance_Review__c(Employee__c = e.get('Aditya Singh').Id, Reviewer__c = myEmp, Review_Cycle__c = 'Mid-Year', Review_Year__c = yr, Status__c = 'Not Started', Due_Date__c = Date.today().addDays(-4)));
reviews.add(new Performance_Review__c(Employee__c = e.get('Karthik Subramanian').Id, Reviewer__c = myEmp, Review_Cycle__c = 'Mid-Year', Review_Year__c = yr, Status__c = 'Manager Review', Self_Rating__c = 3.5, Due_Date__c = Date.today().addDays(5), Self_Assessment__c = 'Delivered the MuleSoft migration; struggled with on-call load.'));
reviews.add(new Performance_Review__c(Employee__c = myEmp, Reviewer__c = e.get('Vikram Mehta').Id, Review_Cycle__c = 'Mid-Year', Review_Year__c = yr, Status__c = 'Self Assessment', Due_Date__c = Date.today().addDays(12)));
insert reviews;

// ---------------- Goals (company -> department -> individual) ----------------
Goal__c company = new Goal__c(Name = 'Grow ARR by 40%', Goal_Type__c = 'Company', Framework__c = 'OKR', Key_Result__c = 'ARR from 25 Cr to 35 Cr', Target_Value__c = 35, Current_Value__c = 29, Unit__c = 'Cr', Status__c = 'On Track', Due_Date__c = Date.newInstance(Date.today().year(), 12, 31));
insert company;
Goal__c engGoal = new Goal__c(Name = 'Ship Platform v3', Goal_Type__c = 'Department', Department__c = dept.get('ENG'), Parent_Goal__c = company.Id, Framework__c = 'OKR', Key_Result__c = 'Release 12 platform epics', Target_Value__c = 12, Current_Value__c = 7, Unit__c = 'epics', Status__c = 'On Track', Due_Date__c = Date.today().addDays(60));
insert engGoal;
insert new List<Goal__c>{
    new Goal__c(Name = 'Reduce release cycle time', Employee__c = myEmp, Parent_Goal__c = engGoal.Id, Goal_Type__c = 'Individual', Framework__c = 'KPI', Key_Result__c = 'Lead time from commit to prod (days)', Target_Value__c = 10, Current_Value__c = 6, Unit__c = 'pts', Weightage__c = 40, Status__c = 'On Track', Due_Date__c = Date.today().addDays(45)),
    new Goal__c(Name = 'Hire 3 engineers', Employee__c = myEmp, Parent_Goal__c = engGoal.Id, Goal_Type__c = 'Individual', Framework__c = 'SMART', Key_Result__c = 'Offers accepted', Target_Value__c = 3, Current_Value__c = 1, Unit__c = 'hires', Weightage__c = 30, Status__c = 'At Risk', Due_Date__c = Date.today().addDays(30)),
    new Goal__c(Name = 'Payments API v2', Employee__c = e.get('Priya Sharma').Id, Parent_Goal__c = engGoal.Id, Goal_Type__c = 'Individual', Framework__c = 'OKR', Key_Result__c = 'Endpoints migrated', Target_Value__c = 20, Current_Value__c = 16, Unit__c = 'endpoints', Status__c = 'On Track', Due_Date__c = Date.today().addDays(20)),
    new Goal__c(Name = 'Test automation coverage', Employee__c = e.get('Aditya Singh').Id, Parent_Goal__c = engGoal.Id, Goal_Type__c = 'Individual', Framework__c = 'KPI', Key_Result__c = 'Automated regression %', Target_Value__c = 80, Current_Value__c = 45, Unit__c = '%', Status__c = 'Behind', Due_Date__c = Date.today().addDays(25))
};

// ---------------- Compensation ------------------------------------------------
List<Compensation_Revision__c> comps = new List<Compensation_Revision__c>();
for (String nm : new List<String>{ 'Neha Gupta', 'Pooja Joshi', 'Tanvi Agarwal', 'Emily Carter', 'Ayesha Siddiqui' }) {
    Employee__c x = e.get(nm);
    comps.add(new Compensation_Revision__c(Employee__c = x.Id, Reason__c = 'Annual Increment', Status__c = 'Approved', Effective_Date__c = Date.today().addMonths(-7),
        New_CTC__c = (x.Annual_CTC__c * 1.1).setScale(0), Justification__c = 'Annual merit increase.'));
}
comps.add(new Compensation_Revision__c(Employee__c = e.get('Priya Sharma').Id, Reason__c = 'Promotion', Status__c = 'Proposed', Effective_Date__c = Date.today().addMonths(1),
    New_CTC__c = 2900000, Justification__c = 'Promotion to Tech Lead recommended after mid-year review.'));
insert comps;
for (Compensation_Revision__c c : comps) if (c.Status__c == 'Approved') c.Status__c = 'Applied';
update comps;

// ---------------- Recognition -----------------------------------------------
insert new List<Recognition__c>{
    new Recognition__c(Giver__c = myEmp, Recipient__c = e.get('Priya Sharma').Id, Badge__c = 'Above and Beyond', Points__c = 30, Message__c = 'Stayed late to unblock the payments go-live. Thank you!'),
    new Recognition__c(Giver__c = e.get('Priya Sharma').Id, Recipient__c = e.get('Neha Gupta').Id, Badge__c = 'Team Player', Points__c = 10, Message__c = 'Jumped in on code reviews all sprint.'),
    new Recognition__c(Giver__c = e.get('Meera Iyer').Id, Recipient__c = e.get('Tanvi Agarwal').Id, Badge__c = 'Innovator', Points__c = 20, Message__c = 'The new design system is beautiful and saves everyone time.'),
    new Recognition__c(Giver__c = e.get('Lakshmi Pillai').Id, Recipient__c = e.get('Ayesha Siddiqui').Id, Badge__c = 'Customer Hero', Points__c = 25, Message__c = 'Saved the Acme renewal with an amazing exec presentation.'),
    new Recognition__c(Giver__c = e.get('Vikram Mehta').Id, Recipient__c = myEmp, Badge__c = 'Leadership', Points__c = 20, Message__c = 'Great job growing the team and keeping delivery on track.'),
    new Recognition__c(Giver__c = e.get('Sameer Khan').Id, Recipient__c = e.get('Kavya Krishnan').Id, Badge__c = 'Quality Champion', Points__c = 15, Message__c = 'Zero-downtime laptop refresh for 40 people.')
};

// ---------------- Engagement surveys ----------------------------------------
Pulse_Survey__c enps = new Pulse_Survey__c(Name = 'Q4 eNPS', Question__c = 'How likely are you to recommend Nimbus as a place to work? (0-10)', Survey_Type__c = 'eNPS', Anonymous__c = true, Active__c = true, Start_Date__c = Date.today().addDays(-10), End_Date__c = Date.today().addDays(20));
Pulse_Survey__c onbFeedback = new Pulse_Survey__c(Name = 'New joiner onboarding feedback', Question__c = 'How smooth was your onboarding experience? (0-10)', Survey_Type__c = 'Onboarding Feedback', Anonymous__c = true, Active__c = false, Start_Date__c = Date.today().addDays(-90), End_Date__c = Date.today().addDays(-30));
insert new List<Pulse_Survey__c>{ enps, onbFeedback };
List<Survey_Response__c> resp = new List<Survey_Response__c>();
List<Integer> scores = new List<Integer>{ 9, 10, 8, 7, 9, 6, 10, 9, 8, 4, 9, 7, 10, 8, 9, 5, 9, 10, 8, 9, 7, 9, 3, 10 };
List<Id> depts = dept.values();
for (Integer k = 0; k < scores.size(); k++) {
    resp.add(new Survey_Response__c(Pulse_Survey__c = enps.Id, Score__c = scores[k], Department__c = depts[Math.mod(k, depts.size())], Respondent_Key__c = 'seed-enps-' + k,
        Comment__c = scores[k] <= 6 ? 'Workload has been heavy this quarter.' : (scores[k] >= 9 ? 'Great team and learning opportunities.' : null)));
}
insert resp;
// close the onboarding survey only after responses so the "closed" validation does not block seeding
update new Pulse_Survey__c(Id = onbFeedback.Id, Active__c = true);
List<Survey_Response__c> resp2 = new List<Survey_Response__c>();
for (Integer k = 0; k < 8; k++) resp2.add(new Survey_Response__c(Pulse_Survey__c = onbFeedback.Id, Score__c = 7 + Math.mod(k, 4), Respondent_Key__c = 'seed-onb-' + k));
insert resp2;
update new Pulse_Survey__c(Id = onbFeedback.Id, Active__c = false);

// ---------------- Recruitment ---------------------------------------------
Job_Requisition__c r1 = new Job_Requisition__c(Name = 'Senior Salesforce Developer', Department__c = dept.get('ENG'), Location__c = loc.get('Hyderabad'), Designation__c = desig.get('Senior Software Engineer'), Hiring_Manager__c = myEmp, Openings__c = 2, Priority__c = 'High', Status__c = 'Draft', Internal_Posting__c = true, Required_Skills__c = 'Apex;LWC;Integration;Testing', Min_Experience_Years__c = 5, Budget_Max_CTC__c = 3000000, Target_Hire_Date__c = Date.today().addDays(45), Job_Description__c = 'Design and build scalable Salesforce solutions with Apex, LWC and integrations.');
Job_Requisition__c r2 = new Job_Requisition__c(Name = 'Customer Success Manager', Department__c = dept.get('CS'), Location__c = loc.get('Pune'), Designation__c = desig.get('Customer Success Manager'), Hiring_Manager__c = e.get('Lakshmi Pillai').Id, Openings__c = 1, Priority__c = 'Medium', Status__c = 'Draft', Internal_Posting__c = true, Required_Skills__c = 'Communication;Salesforce;Renewals', Budget_Max_CTC__c = 1800000);
Job_Requisition__c r3 = new Job_Requisition__c(Name = 'Account Executive - US East', Department__c = dept.get('SAL'), Location__c = loc.get('New York'), Designation__c = desig.get('Account Executive'), Hiring_Manager__c = e.get('Daniel Brooks').Id, Openings__c = 2, Priority__c = 'Critical', Status__c = 'Draft', Required_Skills__c = 'Negotiation;CRM;Prospecting', Budget_Max_CTC__c = 6000000);
Job_Requisition__c r4 = new Job_Requisition__c(Name = 'Product Designer', Department__c = dept.get('PRD'), Location__c = loc.get('Bengaluru'), Designation__c = desig.get('Product Designer'), Hiring_Manager__c = e.get('Meera Iyer').Id, Openings__c = 1, Status__c = 'Pending Approval', Required_Skills__c = 'Figma;UX Research;Design Systems');
insert new List<Job_Requisition__c>{ r1, r2, r3, r4 };
r1.Status__c = 'Open'; r2.Status__c = 'Open'; r3.Status__c = 'Open';
update new List<Job_Requisition__c>{ r1, r2, r3 };
update new List<Job_Requisition__c>{ new Job_Requisition__c(Id = r1.Id, Posted_On__c = Date.today().addDays(-24)), new Job_Requisition__c(Id = r3.Id, Posted_On__c = Date.today().addDays(-41)) };

List<Candidate__c> cands = new List<Candidate__c>{
    new Candidate__c(Name = 'Arvind Swamy', Email__c = 'arvind.s@example.com', Job_Requisition__c = r1.Id, Stage__c = 'Interview', Source__c = 'LinkedIn', Current_Company__c = 'Infosys', Experience_Years__c = 6, Current_CTC__c = 2200000, Expected_CTC__c = 2800000, Notice_Period_Days__c = 60, Skills__c = 'Apex;LWC;Integration;Java',
        Resume_Text__c = 'Salesforce developer with 6 years of experience building Apex triggers, LWC apps and REST integrations for banking clients. Led a team of 4. Certified Platform Developer II.'),
    new Candidate__c(Name = 'Bhavana Rao', Email__c = 'bhavana.r@example.com', Job_Requisition__c = r1.Id, Stage__c = 'Offer', Source__c = 'Referral', Referred_By__c = e.get('Priya Sharma').Id, Current_Company__c = 'Deloitte', Experience_Years__c = 7, Expected_CTC__c = 2900000, Offered_CTC__c = 2850000, Skills__c = 'Apex;LWC;Integration;Testing', Expected_Joining_Date__c = Date.today().addDays(30),
        Resume_Text__c = 'Technical lead for Salesforce implementations across sales and service clouds. Strong in Apex, LWC, testing and CI/CD.'),
    new Candidate__c(Name = 'Chetan Arora', Email__c = 'chetan.a@example.com', Job_Requisition__c = r1.Id, Stage__c = 'Screening', Source__c = 'Job Portal', Experience_Years__c = 4, Skills__c = 'Apex;Visualforce'),
    new Candidate__c(Name = 'Nisha Kulkarni', Email__c = 'nisha.k@example.com', Job_Requisition__c = r2.Id, Stage__c = 'Applied', Source__c = 'Company Website', Experience_Years__c = 5, Skills__c = 'Communication;Renewals'),
    new Candidate__c(Name = 'Michael Chen', Email__c = 'm.chen@example.com', Job_Requisition__c = r3.Id, Stage__c = 'Interview', Source__c = 'Agency', Experience_Years__c = 8, Skills__c = 'Negotiation;CRM;Prospecting', Expected_CTC__c = 5800000),
    new Candidate__c(Name = 'Olivia Martinez', Email__c = 'olivia.m@example.com', Job_Requisition__c = r3.Id, Stage__c = 'Rejected', Source__c = 'LinkedIn', Experience_Years__c = 3, Skills__c = 'CRM', Rejection_Reason__c = 'Insufficient enterprise experience'),
    new Candidate__c(Name = 'Ritu Saxena', Job_Requisition__c = r2.Id, Stage__c = 'Screening', Source__c = 'Internal', Internal_Employee__c = e.get('Ritu Saxena').Id, Skills__c = 'Communication;Onboarding')
};
insert cands;
insert new List<Interview__c>{
    new Interview__c(Candidate__c = cands[0].Id, Round__c = 'Technical 1', Interviewer__c = UserInfo.getUserId(), Scheduled_At__c = System.now().addDays(-3), Status__c = 'Completed', Rating__c = 4, Recommendation__c = 'Hire', Feedback__c = 'Strong Apex fundamentals, good trigger design.'),
    new Interview__c(Candidate__c = cands[0].Id, Round__c = 'Managerial', Interviewer__c = UserInfo.getUserId(), Scheduled_At__c = System.now().addDays(2), Status__c = 'Scheduled', Meeting_Link__c = 'https://zoom.us/j/000000'),
    new Interview__c(Candidate__c = cands[1].Id, Round__c = 'Technical 1', Interviewer__c = UserInfo.getUserId(), Scheduled_At__c = System.now().addDays(-10), Status__c = 'Completed', Rating__c = 5, Recommendation__c = 'Strong Hire'),
    new Interview__c(Candidate__c = cands[1].Id, Round__c = 'HR', Interviewer__c = UserInfo.getUserId(), Scheduled_At__c = System.now().addDays(-6), Status__c = 'Completed', Rating__c = 4.5, Recommendation__c = 'Hire'),
    new Interview__c(Candidate__c = cands[4].Id, Round__c = 'Screening', Interviewer__c = UserInfo.getUserId(), Scheduled_At__c = System.now().addDays(1), Status__c = 'Scheduled')
};

// ---------------- Exit in progress -----------------------------------------
Exit_Process__c ex = new Exit_Process__c(Employee__c = e.get('Suresh Babu').Id, Exit_Type__c = 'Resignation', Exit_Reason__c = 'Better Opportunity',
    Resignation_Date__c = Date.today().addDays(-25), Notice_Period_Days__c = 60, KT_Recipient__c = e.get('Ayesha Siddiqui').Id, Knowledge_Transfer_Status__c = 'In Progress');
insert ex;
List<Exit_Task__c> et = [SELECT Id, Assigned_Team__c FROM Exit_Task__c WHERE Exit_Process__c = :ex.Id ORDER BY Sequence__c];
for (Integer k = 0; k < et.size(); k++) if (k < 3) et[k].Status__c = 'Completed';
update et;

// ---------------- Onboarding progress for new joiners -----------------------
List<Onboarding_Task__c> ot = [SELECT Id, Due_Date__c, Onboarding__r.Employee__r.Name FROM Onboarding_Task__c ORDER BY Sequence__c];
List<Onboarding_Task__c> done = new List<Onboarding_Task__c>();
for (Onboarding_Task__c t : ot) {
    Boolean ishaan = t.Onboarding__r.Employee__r.Name == 'Ishaan Malhotra';
    if ((ishaan && t.Due_Date__c <= Date.today().addDays(-3)) || (!ishaan && t.Due_Date__c < Date.today())) done.add(new Onboarding_Task__c(Id = t.Id, Status__c = 'Completed'));
}
if (!done.isEmpty()) update done;
List<Employee_Document__c> docs = [SELECT Id, Document_Type__c, Employee__r.Name FROM Employee_Document__c];
for (Employee_Document__c d : docs) {
    if (d.Employee__r.Name == 'Ishaan Malhotra') d.Verification_Status__c = d.Document_Type__c == 'Bank Proof' ? 'Uploaded' : 'Verified';
    else if (d.Document_Type__c == 'Offer Letter') d.Verification_Status__c = 'Verified';
}
update docs;
insert new Employee_Document__c(Name = 'Work Visa (H-1B)', Employee__c = e.get('Daniel Brooks').Id, Document_Type__c = 'Visa / Work Permit', Verification_Status__c = 'Verified', Expiry_Date__c = Date.today().addDays(21), Mandatory__c = true, Document_Reference__c = '4471');

insert new Mentorship__c(Mentor__c = e.get('Priya Sharma').Id, Mentee__c = e.get('Rahul Verma').Id, Focus_Area__c = 'Apex design patterns', Status__c = 'Active', Start_Date__c = Date.today().addDays(-30));

// Run the nightly automation once (attrition indicators, celebrations, reminders)
System.debug('Daily job: ' + PS_DailyJob.run());
System.debug('Seed part 3 complete.');
