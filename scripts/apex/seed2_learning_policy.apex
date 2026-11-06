// PeopleSphere sample data - part 2: checklist templates, learning, policies, holidays, announcements.
Organization__c org = [SELECT Id FROM Organization__c WHERE Name = 'Nimbus Technologies' LIMIT 1];
Map<String, Id> dept = new Map<String, Id>();
for (Department__c x : [SELECT Id, Code__c FROM Department__c WHERE Organization__c = :org.Id]) dept.put(x.Code__c, x.Id);
Map<String, Id> loc = new Map<String, Id>();
for (Location__c x : [SELECT Id, City__c FROM Location__c WHERE Organization__c = :org.Id]) loc.put(x.City__c, x.Id);

// ---------------- Checklist templates (configurable workflows) -----------
Checklist_Template__c engOnb = new Checklist_Template__c(Name = 'Engineering Onboarding', Process_Type__c = 'Onboarding', Organization__c = org.Id,
    Department__c = dept.get('ENG'), Duration_Days__c = 45, Active__c = true, Description__c = 'Engineering-specific onboarding with dev environment setup and code walkthroughs.');
Checklist_Template__c stdOnb = new Checklist_Template__c(Name = 'Standard Onboarding', Process_Type__c = 'Onboarding', Organization__c = org.Id,
    Duration_Days__c = 30, Active__c = true, Description__c = 'Default onboarding for all departments.');
Checklist_Template__c stdExit = new Checklist_Template__c(Name = 'Standard Offboarding', Process_Type__c = 'Offboarding', Organization__c = org.Id,
    Active__c = true, Description__c = 'Coordinated clearance across Manager, HR, IT and Finance.');
insert new List<Checklist_Template__c>{ engOnb, stdOnb, stdExit };

List<Checklist_Template_Item__c> items = new List<Checklist_Template_Item__c>();
List<List<Object>> engItems = new List<List<Object>>{
    new List<Object>{ 'Send offer pack and welcome email', 'HR', 'Orientation', -5, true },
    new List<Object>{ 'Collect signed offer letter and ID proofs', 'HR', 'Documentation', -3, true },
    new List<Object>{ 'Background verification', 'HR', 'Compliance', -1, true },
    new List<Object>{ 'Provision laptop (16GB+, dev image)', 'IT', 'Equipment', -2, true },
    new List<Object>{ 'Create SSO, email, GitHub and Salesforce sandbox access', 'IT', 'Access', -1, true },
    new List<Object>{ 'Issue access card', 'Facilities', 'Equipment', 0, true },
    new List<Object>{ 'Payroll, PF and bank setup', 'Finance', 'Documentation', 3, true },
    new List<Object>{ 'Complete joining forms and emergency contacts', 'Employee', 'Documentation', 1, true },
    new List<Object>{ 'Acknowledge handbook and IT security policy', 'Employee', 'Compliance', 2, true },
    new List<Object>{ 'Architecture walkthrough and codebase tour', 'Manager', 'Orientation', 2, true },
    new List<Object>{ 'Assign onboarding buddy', 'Manager', 'Orientation', 0, true },
    new List<Object>{ 'Ship first pull request', 'Employee', 'Training', 14, false },
    new List<Object>{ 'Complete secure coding and compliance training', 'Learning', 'Training', 21, true },
    new List<Object>{ '30-60-90 day plan review', 'Manager', 'Orientation', 30, true }
};
Integer seq = 1;
for (List<Object> r : engItems) {
    items.add(new Checklist_Template_Item__c(Checklist_Template__c = engOnb.Id, Name = (String) r[0], Assigned_Team__c = (String) r[1],
        Category__c = (String) r[2], Days_Offset__c = (Integer) r[3], Mandatory__c = (Boolean) r[4], Sequence__c = seq++));
}
seq = 1;
for (List<Object> r : new List<List<Object>>{
        new List<Object>{ 'Approve resignation and confirm last day', 'Manager', 'Clearance', 0, true },
        new List<Object>{ 'Knowledge transfer document and handover sessions', 'Manager', 'Knowledge Transfer', -14, true },
        new List<Object>{ 'Exit interview', 'HR', 'Clearance', -5, true },
        new List<Object>{ 'Revoke SSO, email and SaaS licences', 'IT', 'Access', 0, true },
        new List<Object>{ 'Clear advances and pending expense claims', 'Finance', 'Clearance', -3, true },
        new List<Object>{ 'Full and final settlement', 'Finance', 'Settlement', 30, true },
        new List<Object>{ 'Experience and relieving letter', 'HR', 'Documentation', 0, true } }) {
    items.add(new Checklist_Template_Item__c(Checklist_Template__c = stdExit.Id, Name = (String) r[0], Assigned_Team__c = (String) r[1],
        Category__c = (String) r[2], Days_Offset__c = (Integer) r[3], Mandatory__c = (Boolean) r[4], Sequence__c = seq++));
}
insert items;

// ---------------- Learning catalogue ------------------------------------
Id instructor = [SELECT Id FROM Employee__c WHERE Name = 'Priya Sharma' LIMIT 1].Id;
List<Learning_Course__c> courses = new List<Learning_Course__c>{
    new Learning_Course__c(Name = 'Code of Conduct & Ethics', Course_Code__c = 'CMP-101', Category__c = 'Compliance', Delivery_Mode__c = 'Video', Duration_Hours__c = 1, Mandatory__c = true, Certification_Validity_Months__c = 12, Passing_Score__c = 70, Due_In_Days__c = 30, Skills_Covered__c = 'ethics;compliance', Content_URL__c = 'https://trailhead.salesforce.com', Description__c = 'Our values, conflicts of interest, gifts, and how to speak up.'),
    new Learning_Course__c(Name = 'Information Security Essentials', Course_Code__c = 'SEC-101', Category__c = 'Information Security', Delivery_Mode__c = 'Video', Duration_Hours__c = 1.5, Mandatory__c = true, Certification_Validity_Months__c = 12, Passing_Score__c = 80, Due_In_Days__c = 21, Skills_Covered__c = 'security;phishing awareness', Content_URL__c = 'https://trailhead.salesforce.com', Description__c = 'Phishing, passwords, data classification and incident reporting.'),
    new Learning_Course__c(Name = 'Prevention of Sexual Harassment (POSH)', Course_Code__c = 'CMP-102', Category__c = 'Compliance', Delivery_Mode__c = 'Video', Duration_Hours__c = 1, Mandatory__c = true, Certification_Validity_Months__c = 24, Passing_Score__c = 70, Due_In_Days__c = 30, Skills_Covered__c = 'compliance', Description__c = 'Legal framework, reporting channels and the Internal Committee.'),
    new Learning_Course__c(Name = 'Apex Fundamentals', Course_Code__c = 'TEC-201', Category__c = 'Technical', Delivery_Mode__c = 'Blended', Level__c = 'Beginner', Duration_Hours__c = 8, Target_Department__c = dept.get('ENG'), Instructor__c = instructor, Passing_Score__c = 70, Skills_Covered__c = 'apex;testing', Content_URL__c = 'https://trailhead.salesforce.com/content/learn/modules/apex_database'),
    new Learning_Course__c(Name = 'Lightning Web Components in Depth', Course_Code__c = 'TEC-202', Category__c = 'Technical', Delivery_Mode__c = 'Virtual Instructor-led', Level__c = 'Intermediate', Duration_Hours__c = 12, Target_Department__c = dept.get('ENG'), Instructor__c = instructor, Skills_Covered__c = 'lwc;javascript', Content_URL__c = 'https://trailhead.salesforce.com/content/learn/modules/lightning-web-components-basics'),
    new Learning_Course__c(Name = 'Integration Patterns & APIs', Course_Code__c = 'TEC-301', Category__c = 'Technical', Delivery_Mode__c = 'Classroom', Level__c = 'Advanced', Duration_Hours__c = 10, Target_Department__c = dept.get('ENG'), Skills_Covered__c = 'integration;rest;mulesoft'),
    new Learning_Course__c(Name = 'Test Automation with Selenium', Course_Code__c = 'TEC-210', Category__c = 'Technical', Delivery_Mode__c = 'Video', Level__c = 'Intermediate', Duration_Hours__c = 6, Skills_Covered__c = 'automation;selenium;testing'),
    new Learning_Course__c(Name = 'First-time Manager Program', Course_Code__c = 'LDR-101', Category__c = 'Leadership', Delivery_Mode__c = 'Blended', Level__c = 'Intermediate', Duration_Hours__c = 16, Skills_Covered__c = 'leadership;coaching;feedback'),
    new Learning_Course__c(Name = 'Agile & Scrum Practitioner', Course_Code__c = 'LDR-110', Category__c = 'Leadership', Delivery_Mode__c = 'Virtual Instructor-led', Duration_Hours__c = 8, Skills_Covered__c = 'agile;scrum'),
    new Learning_Course__c(Name = 'Consultative Selling', Course_Code__c = 'SAL-101', Category__c = 'Soft Skills', Delivery_Mode__c = 'Classroom', Duration_Hours__c = 6, Target_Department__c = dept.get('SAL'), Skills_Covered__c = 'negotiation;prospecting;crm'),
    new Learning_Course__c(Name = 'Customer Renewals Playbook', Course_Code__c = 'CS-101', Category__c = 'Product', Delivery_Mode__c = 'Document', Duration_Hours__c = 3, Target_Department__c = dept.get('CS'), Skills_Covered__c = 'renewals;salesforce'),
    new Learning_Course__c(Name = 'Figma for Product Teams', Course_Code__c = 'PRD-101', Category__c = 'Technical', Delivery_Mode__c = 'Video', Duration_Hours__c = 4, Skills_Covered__c = 'figma;design systems'),
    new Learning_Course__c(Name = 'Effective Communication', Course_Code__c = 'SFT-101', Category__c = 'Soft Skills', Delivery_Mode__c = 'Video', Duration_Hours__c = 2, Skills_Covered__c = 'communication;presentation'),
    new Learning_Course__c(Name = 'Fire & Workplace Safety', Course_Code__c = 'SAF-101', Category__c = 'Safety', Delivery_Mode__c = 'Video', Duration_Hours__c = 0.5, Mandatory__c = false, Skills_Covered__c = 'safety')
};
for (Learning_Course__c c : courses) { c.Active__c = true; if (c.Passing_Score__c == null) c.Passing_Score__c = 70; if (c.Due_In_Days__c == null) c.Due_In_Days__c = 45; if (c.Level__c == null) c.Level__c = 'Beginner'; }
insert courses;  // mandatory courses are auto-assigned to every active employee by the course trigger
Map<String, Learning_Course__c> cByCode = new Map<String, Learning_Course__c>();
for (Learning_Course__c c : courses) cByCode.put(c.Course_Code__c, c);
update new Learning_Course__c(Id = cByCode.get('TEC-202').Id, Prerequisite_Course__c = cByCode.get('TEC-201').Id);
update new Learning_Course__c(Id = cByCode.get('TEC-301').Id, Prerequisite_Course__c = cByCode.get('TEC-201').Id);

List<Quiz_Question__c> qs = new List<Quiz_Question__c>();
qs.add(new Quiz_Question__c(Course__c = cByCode.get('CMP-101').Id, Sequence__c = 1, Question__c = 'A vendor offers you an expensive gift during a contract negotiation. What should you do?', Option_A__c = 'Accept it quietly', Option_B__c = 'Decline and report it to your manager/compliance', Option_C__c = 'Accept and share it with the team', Option_D__c = 'Ask for a bigger gift', Correct_Option__c = 'B', Explanation__c = 'Gifts that could influence business decisions must be declined and disclosed.'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('CMP-101').Id, Sequence__c = 2, Question__c = 'You notice a colleague falsifying expense claims. The right first step is to:', Option_A__c = 'Ignore it', Option_B__c = 'Confront them publicly', Option_C__c = 'Report it through the speak-up channel', Option_D__c = 'Post about it on social media', Correct_Option__c = 'C', Explanation__c = 'Use the confidential speak-up channel; retaliation is prohibited.'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('CMP-101').Id, Sequence__c = 3, Question__c = 'A conflict of interest must be:', Option_A__c = 'Declared as soon as it arises', Option_B__c = 'Declared only if asked', Option_C__c = 'Kept private', Option_D__c = 'Declared at exit', Correct_Option__c = 'A'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('SEC-101').Id, Sequence__c = 1, Question__c = 'An email asks you to urgently reset your password via a link. You should:', Option_A__c = 'Click the link immediately', Option_B__c = 'Forward it to colleagues', Option_C__c = 'Report it as phishing and not click', Option_D__c = 'Reply with your password', Correct_Option__c = 'C', Explanation__c = 'Unexpected urgent requests with links are classic phishing.'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('SEC-101').Id, Sequence__c = 2, Question__c = 'Which is the strongest password practice?', Option_A__c = 'Reuse one strong password', Option_B__c = 'Use a password manager and MFA', Option_C__c = 'Write passwords on sticky notes', Option_D__c = 'Share passwords with your manager', Correct_Option__c = 'B'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('SEC-101').Id, Sequence__c = 3, Question__c = 'Customer personal data classified as Confidential may be stored on:', Option_A__c = 'Personal Google Drive', Option_B__c = 'Approved company systems only', Option_C__c = 'A USB stick', Option_D__c = 'WhatsApp', Correct_Option__c = 'B'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('CMP-102').Id, Sequence__c = 1, Question__c = 'Who handles sexual harassment complaints under POSH?', Option_A__c = 'The Internal Committee', Option_B__c = 'Only the CEO', Option_C__c = 'Line manager alone', Option_D__c = 'Nobody', Correct_Option__c = 'A'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('CMP-102').Id, Sequence__c = 2, Question__c = 'Retaliation against a complainant is:', Option_A__c = 'Allowed if the complaint fails', Option_B__c = 'Strictly prohibited', Option_C__c = 'Up to the manager', Option_D__c = 'Allowed after 6 months', Correct_Option__c = 'B'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('TEC-201').Id, Sequence__c = 1, Question__c = 'What is the minimum code coverage to deploy Apex to production?', Option_A__c = '50%', Option_B__c = '65%', Option_C__c = '75%', Option_D__c = '100%', Correct_Option__c = 'C'));
qs.add(new Quiz_Question__c(Course__c = cByCode.get('TEC-201').Id, Sequence__c = 2, Question__c = 'Which keyword enforces sharing rules in an Apex class?', Option_A__c = 'with sharing', Option_B__c = 'global', Option_C__c = 'virtual', Option_D__c = 'transient', Correct_Option__c = 'A'));
insert qs;

// Complete most mandatory training (issues certifications), leave some open/overdue
List<Learning_Enrollment__c> enr = [SELECT Id, Employee__r.Name FROM Learning_Enrollment__c WHERE Course__r.Mandatory__c = true ORDER BY Employee__r.Name, Course__r.Course_Code__c];
List<Learning_Enrollment__c> upd = new List<Learning_Enrollment__c>();
String me = UserInfo.getName();
for (Integer k = 0; k < enr.size(); k++) {
    Learning_Enrollment__c e = enr[k];
    if (e.Employee__r.Name == me) continue; // leave the demo user's courses open to try the quiz
    if (Math.mod(k, 5) == 0) upd.add(new Learning_Enrollment__c(Id = e.Id, Due_Date__c = Date.today().addDays(-6), Status__c = 'Overdue'));
    else if (Math.mod(k, 7) == 0) upd.add(new Learning_Enrollment__c(Id = e.Id, Status__c = 'In Progress', Progress_Percent__c = 40));
    else upd.add(new Learning_Enrollment__c(Id = e.Id, Status__c = 'Completed', Score__c = 80 + Math.mod(k, 20), Attempts__c = 1));
}
update upd;
// a couple of certifications close to expiry for the compliance control centre
List<Certification__c> certs = [SELECT Id FROM Certification__c ORDER BY CreatedDate LIMIT 3];
if (certs.size() == 3) {
    certs[0].Expires_On__c = Date.today().addDays(12);
    certs[1].Expires_On__c = Date.today().addDays(25);
    certs[2].Expires_On__c = Date.today().addDays(-3);
    update certs;
}
// technical enrollments for the engineering team
List<Learning_Enrollment__c> tech = new List<Learning_Enrollment__c>();
for (Employee__c e : [SELECT Id FROM Employee__c WHERE Department__r.Code__c = 'ENG' AND Status__c = 'Active' AND Name != :me LIMIT 10]) {
    tech.add(new Learning_Enrollment__c(Employee__c = e.Id, Course__c = cByCode.get('TEC-201').Id, Status__c = 'Completed', Score__c = 88, Assignment_Source__c = 'Department Rule'));
}
insert tech;

// ---------------- HR policies (also the assistant's knowledge base) ------
insert new List<HR_Policy__c>{
    new HR_Policy__c(Name = 'Leave Policy', Category__c = 'Leave', Version__c = '3.0', Effective_Date__c = Date.newInstance(2026, 1, 1), Active__c = true, Requires_Acknowledgement__c = false,
        Keywords__c = 'leave, vacation, casual, sick, earned, holiday, time off, carry forward',
        Summary__c = 'Annual entitlement of 12 casual, 10 sick and 15 earned leaves, how to apply and carry-forward rules.',
        Policy_Body__c = 'Every full-time employee receives 12 casual leaves, 10 sick leaves and 15 earned leaves per calendar year, credited on 1 January and pro-rated for new joiners. Casual leave cannot be carried forward and lapses on 31 December. Up to 30 earned leaves can be carried forward to the next year; earned leave beyond that is encashed at basic pay. Sick leave of more than two consecutive days requires a medical certificate. Apply for leave in PeopleSphere at least three working days in advance for planned leave; your reporting manager approves it. Weekends and public holidays that fall within a leave period are not counted. Maternity leave is 26 weeks and paternity leave is 10 working days. Bereavement leave of 5 days is available for immediate family.'),
    new HR_Policy__c(Name = 'Remote & Hybrid Work Policy', Category__c = 'Remote Work', Version__c = '2.1', Effective_Date__c = Date.newInstance(2025, 7, 1), Active__c = true, Requires_Acknowledgement__c = true,
        Keywords__c = 'remote, wfh, work from home, hybrid, office days, internet allowance',
        Summary__c = 'Hybrid employees work from the office at least 3 days a week; WFH requests go through PeopleSphere.',
        Policy_Body__c = 'Nimbus follows a hybrid model. Hybrid employees work from the office at least three days per week, with Tuesday and Thursday as team anchor days. Fully remote roles are approved by the department head and HR. Occasional work from home must be requested in PeopleSphere as a Work From Home leave type and approved by your manager. Employees working remotely receive a monthly internet allowance of INR 1,500, claimed through expense claims. You must work from a secure location, use the company VPN and never use public Wi-Fi without the VPN. Core collaboration hours are 11:00 to 17:00 local time.'),
    new HR_Policy__c(Name = 'Employee Handbook & Code of Conduct', Category__c = 'Code of Conduct', Version__c = '4.0', Effective_Date__c = Date.newInstance(2026, 4, 1), Active__c = true, Requires_Acknowledgement__c = true,
        Keywords__c = 'conduct, ethics, gifts, conflict of interest, dress code, speak up, whistleblower',
        Summary__c = 'Our values, expected behaviour, conflicts of interest, gifts and the speak-up process.',
        Policy_Body__c = 'All employees must act with integrity, treat colleagues with respect and comply with applicable laws. Gifts or hospitality above INR 5,000 in value must be declined or declared to compliance. Any actual or potential conflict of interest, including outside employment or relatives in reporting lines, must be declared in PeopleSphere as soon as it arises. Concerns can be raised confidentially through the speak-up channel or an HR ticket marked Grievance; retaliation against anyone raising a concern in good faith is prohibited and is grounds for dismissal. Dress code is business casual on office days. Company assets must be used responsibly and returned on exit.'),
    new HR_Policy__c(Name = 'Travel & Expense Policy', Category__c = 'Travel & Expense', Version__c = '2.0', Effective_Date__c = Date.newInstance(2025, 4, 1), Active__c = true,
        Keywords__c = 'travel, expense, reimbursement, claim, hotel, flight, per diem, receipt',
        Summary__c = 'What can be claimed, limits, receipts and approval timelines for business expenses.',
        Policy_Body__c = 'Business expenses must be submitted in PeopleSphere within 30 days of being incurred, with receipts for any amount above INR 500. Domestic flights are booked in economy class; hotels up to INR 6,000 per night in metro cities and INR 4,000 elsewhere. The daily meal allowance during travel is INR 1,200. Client entertainment requires prior approval from your manager. Claims are approved by your reporting manager and reimbursed with the next payroll cycle after approval. Personal expenses, alcohol (except approved client entertainment) and traffic fines are not reimbursable.'),
    new HR_Policy__c(Name = 'Information Security Policy', Category__c = 'IT & Security', Version__c = '5.2', Effective_Date__c = Date.newInstance(2026, 2, 1), Active__c = true, Requires_Acknowledgement__c = true,
        Keywords__c = 'security, password, mfa, laptop, data, phishing, vpn, usb, access',
        Summary__c = 'Rules for passwords, MFA, devices, data classification and incident reporting.',
        Policy_Body__c = 'Multi-factor authentication is mandatory on all company systems. Passwords must be at least 14 characters and stored only in the approved password manager. Company laptops are encrypted and must be locked when unattended; never install unapproved software. Confidential and restricted data may only be stored in approved company systems and must never be copied to personal devices, USB drives or personal cloud storage. Report suspected phishing, lost devices or security incidents immediately through an IT Access ticket or the security hotline. Access is granted on least-privilege principles and reviewed quarterly.'),
    new HR_Policy__c(Name = 'Prevention of Sexual Harassment (POSH) Policy', Category__c = 'Anti-Harassment', Version__c = '1.3', Effective_Date__c = Date.newInstance(2025, 1, 1), Active__c = true, Requires_Acknowledgement__c = true,
        Keywords__c = 'harassment, posh, complaint, internal committee, safety, misconduct',
        Summary__c = 'Zero tolerance for sexual harassment; how to report to the Internal Committee.',
        Policy_Body__c = 'Nimbus has zero tolerance for sexual harassment in any form. Complaints can be made to the Internal Committee in writing within three months of the incident, or through a confidential Grievance ticket in PeopleSphere which is routed directly to the Committee. The Committee completes its inquiry within 90 days. Confidentiality of the complainant, respondent and witnesses is protected, and retaliation is prohibited. Interim relief such as transfer or leave can be granted during the inquiry.'),
    new HR_Policy__c(Name = 'Performance Management Policy', Category__c = 'Performance', Version__c = '2.0', Effective_Date__c = Date.newInstance(2026, 1, 1), Active__c = true,
        Keywords__c = 'performance, review, appraisal, rating, goals, okr, promotion, pip',
        Summary__c = 'Quarterly check-ins, annual reviews, the 5-point rating scale and promotion cycles.',
        Policy_Body__c = 'Goals are set as OKRs at the start of each half-year and aligned to department and company goals in PeopleSphere. Managers hold quarterly check-ins; the annual review runs in January with a self-assessment followed by the manager review and calibration. Ratings use a 5-point scale: 1 needs improvement, 2 developing, 3 meets expectations, 4 exceeds, 5 outstanding. Promotions are considered twice a year based on sustained performance and readiness. A performance improvement plan lasts 60 days with fortnightly reviews.'),
    new HR_Policy__c(Name = 'Exit & Notice Period Policy', Category__c = 'Exit', Version__c = '1.1', Effective_Date__c = Date.newInstance(2025, 6, 1), Active__c = true,
        Keywords__c = 'resignation, notice period, exit, relieving, settlement, full and final, buyout',
        Summary__c = 'Notice periods, clearance, full and final settlement and relieving letters.',
        Policy_Body__c = 'The notice period is 60 days for confirmed employees and 15 days during probation. Resignations are submitted in PeopleSphere and approved by the reporting manager. Notice may be shortened by mutual agreement or bought out against basic pay. Clearance from Manager, IT, Finance and HR is coordinated automatically; all company assets must be returned before the last working day. Full and final settlement is processed within 30 days of the last working day, and the experience and relieving letter is issued on completion of clearance.')
};

// ---------------- Holidays ------------------------------------------------
Integer y = Date.today().year();
insert new List<Holiday__c>{
    new Holiday__c(Name = 'Christmas', Holiday_Date__c = Date.newInstance(y, 12, 25), Organization__c = org.Id),
    new Holiday__c(Name = 'New Year', Holiday_Date__c = Date.newInstance(y + 1, 1, 1), Organization__c = org.Id),
    new Holiday__c(Name = 'Republic Day', Holiday_Date__c = Date.newInstance(y + 1, 1, 26), Organization__c = org.Id, Location__c = loc.get('Hyderabad')),
    new Holiday__c(Name = 'Republic Day', Holiday_Date__c = Date.newInstance(y + 1, 1, 26), Organization__c = org.Id, Location__c = loc.get('Bengaluru')),
    new Holiday__c(Name = 'Republic Day', Holiday_Date__c = Date.newInstance(y + 1, 1, 26), Organization__c = org.Id, Location__c = loc.get('Pune')),
    new Holiday__c(Name = 'Thanksgiving', Holiday_Date__c = Date.newInstance(y, 11, 26), Organization__c = org.Id, Location__c = loc.get('New York')),
    new Holiday__c(Name = 'Independence Day (US)', Holiday_Date__c = Date.newInstance(y + 1, 7, 4), Organization__c = org.Id, Location__c = loc.get('New York')),
    new Holiday__c(Name = 'Company Foundation Day', Holiday_Date__c = Date.today().addDays(18), Organization__c = org.Id, Optional__c = true)
};

// ---------------- Announcements -------------------------------------------
insert new List<Announcement__c>{
    new Announcement__c(Name = 'Welcome to PeopleSphere!', Category__c = 'General', Pinned__c = true, Publish_Date__c = Date.today().addDays(-2),
        Body__c = 'Your new home for everything people-related: leave, attendance, learning, reviews, help desk and more. Try the HR Assistant for instant answers.'),
    new Announcement__c(Name = 'Annual review cycle opens soon', Category__c = 'Policy', Publish_Date__c = Date.today().addDays(-1), Expiry_Date__c = Date.today().addDays(45),
        Body__c = 'Self-assessments open on 1 January. Update your goal progress in My Workspace before the cycle starts.'),
    new Announcement__c(Name = 'Quarterly Town Hall', Category__c = 'Event', Publish_Date__c = Date.today(), Event_Date__c = System.now().addDays(9), Event_Location__c = 'Hyderabad HQ + Zoom',
        Body__c = 'Join Ananya for business updates, Q&A and team awards.'),
    new Announcement__c(Name = 'Phishing alert', Category__c = 'IT', Publish_Date__c = Date.today(), Expiry_Date__c = Date.today().addDays(7), Department__c = null,
        Body__c = 'We are seeing fake "payroll update" emails. Do not click links; report them through an IT Access ticket.')
};
System.debug('Seed part 2 complete.');
