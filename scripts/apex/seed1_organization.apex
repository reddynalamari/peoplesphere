// PeopleSphere sample data - part 1: organization structure and employees.
// Run: sf apex run --file scripts/apex/seed1_organization.apex --target-org <alias>
// The running user is linked to "Engineering Manager" so every workspace has data.

Organization__c org = new Organization__c(Name = 'Nimbus Technologies', Legal_Entity_Name__c = 'Nimbus Technologies Pvt Ltd',
    Country__c = 'India', Headquarters__c = 'Hyderabad', Industry__c = 'Technology', Employee_ID_Prefix__c = 'NIM',
    Brand_Color__c = '#0B5CAB', Default_Notice_Period_Days__c = 60, Standard_Work_Hours__c = 9, Active__c = true);
insert org;

Business_Unit__c buTech = new Business_Unit__c(Name = 'Technology & Product', Organization__c = org.Id, Code__c = 'TECH');
Business_Unit__c buOps = new Business_Unit__c(Name = 'Corporate Functions', Organization__c = org.Id, Code__c = 'CORP');
Business_Unit__c buRev = new Business_Unit__c(Name = 'Revenue', Organization__c = org.Id, Code__c = 'REV');
insert new List<Business_Unit__c>{ buTech, buOps, buRev };

Map<String, Department__c> d = new Map<String, Department__c>{
    'ENG' => new Department__c(Name = 'Engineering', Code__c = 'ENG', Business_Unit__c = buTech.Id, Cost_Center__c = 'CC-100', Headcount_Budget__c = 25),
    'PRD' => new Department__c(Name = 'Product & Design', Code__c = 'PRD', Business_Unit__c = buTech.Id, Cost_Center__c = 'CC-110', Headcount_Budget__c = 8),
    'IT'  => new Department__c(Name = 'IT & Security', Code__c = 'IT', Business_Unit__c = buTech.Id, Cost_Center__c = 'CC-120', Headcount_Budget__c = 5),
    'HR'  => new Department__c(Name = 'Human Resources', Code__c = 'HR', Business_Unit__c = buOps.Id, Cost_Center__c = 'CC-200', Headcount_Budget__c = 5),
    'FIN' => new Department__c(Name = 'Finance', Code__c = 'FIN', Business_Unit__c = buOps.Id, Cost_Center__c = 'CC-210', Headcount_Budget__c = 4),
    'SAL' => new Department__c(Name = 'Sales', Code__c = 'SAL', Business_Unit__c = buRev.Id, Cost_Center__c = 'CC-300', Headcount_Budget__c = 10),
    'CS'  => new Department__c(Name = 'Customer Success', Code__c = 'CS', Business_Unit__c = buRev.Id, Cost_Center__c = 'CC-310', Headcount_Budget__c = 8)
};
for (Department__c x : d.values()) { x.Organization__c = org.Id; x.Active__c = true; }
insert d.values();

Map<String, Location__c> l = new Map<String, Location__c>{
    'HYD' => new Location__c(Name = 'Hyderabad HQ', City__c = 'Hyderabad', State__c = 'Telangana', Country__c = 'India', Time_Zone__c = 'Asia/Kolkata', Office_Start_Time__c = '09:30'),
    'BLR' => new Location__c(Name = 'Bengaluru', City__c = 'Bengaluru', State__c = 'Karnataka', Country__c = 'India', Time_Zone__c = 'Asia/Kolkata', Office_Start_Time__c = '10:00'),
    'PUN' => new Location__c(Name = 'Pune', City__c = 'Pune', State__c = 'Maharashtra', Country__c = 'India', Time_Zone__c = 'Asia/Kolkata', Office_Start_Time__c = '09:30'),
    'NYC' => new Location__c(Name = 'New York', City__c = 'New York', State__c = 'NY', Country__c = 'USA', Time_Zone__c = 'America/New_York', Office_Start_Time__c = '09:00')
};
for (Location__c x : l.values()) { x.Organization__c = org.Id; x.Active__c = true; x.Late_Grace_Minutes__c = 15; }
insert l.values();

Map<String, Designation__c> g = new Map<String, Designation__c>{
    'CEO'  => new Designation__c(Name = 'Chief Executive Officer', Grade__c = 'Executive', Level__c = 10, Job_Family__c = 'Leadership'),
    'VP'   => new Designation__c(Name = 'Vice President', Grade__c = 'L8', Level__c = 8, Job_Family__c = 'Leadership', Required_Skills__c = 'leadership;strategy;budgeting'),
    'EM'   => new Designation__c(Name = 'Engineering Manager', Grade__c = 'L6', Level__c = 6, Job_Family__c = 'Engineering', Required_Skills__c = 'leadership;agile;salesforce;architecture'),
    'SSE'  => new Designation__c(Name = 'Senior Software Engineer', Grade__c = 'L4', Level__c = 4, Job_Family__c = 'Engineering', Required_Skills__c = 'apex;lwc;integration;testing'),
    'SE'   => new Designation__c(Name = 'Software Engineer', Grade__c = 'L3', Level__c = 3, Job_Family__c = 'Engineering', Required_Skills__c = 'apex;lwc;git;testing'),
    'QA'   => new Designation__c(Name = 'QA Engineer', Grade__c = 'L3', Level__c = 3, Job_Family__c = 'Engineering', Required_Skills__c = 'testing;automation;selenium'),
    'PM'   => new Designation__c(Name = 'Product Manager', Grade__c = 'L5', Level__c = 5, Job_Family__c = 'Product', Required_Skills__c = 'product strategy;analytics;communication'),
    'DES'  => new Designation__c(Name = 'Product Designer', Grade__c = 'L4', Level__c = 4, Job_Family__c = 'Product', Required_Skills__c = 'figma;ux research;design systems'),
    'HRBP' => new Designation__c(Name = 'HR Business Partner', Grade__c = 'L5', Level__c = 5, Job_Family__c = 'People', Required_Skills__c = 'employee relations;labour law;coaching'),
    'HRE'  => new Designation__c(Name = 'HR Executive', Grade__c = 'L2', Level__c = 2, Job_Family__c = 'People', Required_Skills__c = 'onboarding;hris;communication'),
    'FA'   => new Designation__c(Name = 'Financial Analyst', Grade__c = 'L3', Level__c = 3, Job_Family__c = 'Finance', Required_Skills__c = 'excel;fp&a;accounting'),
    'AE'   => new Designation__c(Name = 'Account Executive', Grade__c = 'L4', Level__c = 4, Job_Family__c = 'Sales', Required_Skills__c = 'negotiation;crm;prospecting'),
    'CSM'  => new Designation__c(Name = 'Customer Success Manager', Grade__c = 'L4', Level__c = 4, Job_Family__c = 'Customer Success', Required_Skills__c = 'communication;salesforce;renewals'),
    'ITA'  => new Designation__c(Name = 'IT Administrator', Grade__c = 'L3', Level__c = 3, Job_Family__c = 'IT', Required_Skills__c = 'networking;security;identity management'),
    'INT'  => new Designation__c(Name = 'Intern', Grade__c = 'L1', Level__c = 1, Job_Family__c = 'Engineering', Required_Skills__c = 'apex;git')
};
for (Designation__c x : g.values()) x.Organization__c = org.Id;
insert g.values();

// name, dept, designation, location, type, status, joined (days ago), rating, skills, dob (yyyy-mm-dd), ctc
List<List<Object>> leaders = new List<List<Object>>{
    new List<Object>{ 'Ananya Rao', 'HR', 'CEO', 'HYD', 'Full-time', 'Active', 2600, 4.8, 'Leadership;Strategy;Fundraising', '1978-03-12', 9500000 },
    new List<Object>{ 'Vikram Mehta', 'ENG', 'VP', 'HYD', 'Full-time', 'Active', 1900, 4.5, 'Leadership;Architecture;Salesforce;Budgeting', '1981-07-22', 6800000 },
    new List<Object>{ 'Sara Thomas', 'HR', 'VP', 'HYD', 'Full-time', 'Active', 1500, 4.4, 'Employee Relations;Leadership;Labour Law', '1983-11-02', 5200000 },
    new List<Object>{ 'Rohan Kapoor', 'SAL', 'VP', 'NYC', 'Full-time', 'Active', 1200, 4.1, 'Negotiation;Leadership;CRM', '1980-01-30', 7200000 }
};

List<Employee__c> wave1 = new List<Employee__c>();
for (List<Object> r : leaders) {
    wave1.add(new Employee__c(Name = (String) r[0], Organization__c = org.Id, Department__c = d.get((String) r[1]).Id,
        Designation__c = g.get((String) r[2]).Id, Location__c = l.get((String) r[3]).Id, Employment_Type__c = (String) r[4],
        Status__c = (String) r[5], Date_of_Joining__c = Date.today().addDays(-(Integer) r[6]), Performance_Rating__c = (Decimal) r[7],
        Skills__c = (String) r[8], Date_of_Birth__c = Date.valueOf((String) r[9]), Annual_CTC__c = (Decimal) r[10],
        Work_Email__c = ((String) r[0]).toLowerCase().replace(' ', '.') + '@nimbus.example', Work_Mode__c = 'Hybrid',
        Background_Check_Status__c = 'Cleared', Education_Verified__c = true, Previous_Employment_Verified__c = true,
        Bank_Details_Verified__c = true, Handbook_Acknowledged__c = true, Critical_Role__c = true, Succession_Readiness__c = '1-2 Years',
        Emergency_Contact_Name__c = 'Family contact', Emergency_Contact_Phone__c = '+91 90000 00000', Recognition_Points__c = 40, Blood_Group__c = 'O+'));
}
insert wave1;
Map<String, Id> byName = new Map<String, Id>();
for (Employee__c e : wave1) byName.put(e.Name, e.Id);
update new List<Employee__c>{
    new Employee__c(Id = byName.get('Vikram Mehta'), Manager__c = byName.get('Ananya Rao')),
    new Employee__c(Id = byName.get('Sara Thomas'), Manager__c = byName.get('Ananya Rao')),
    new Employee__c(Id = byName.get('Rohan Kapoor'), Manager__c = byName.get('Ananya Rao'))
};
update new List<Department__c>{
    new Department__c(Id = d.get('ENG').Id, Department_Head__c = byName.get('Vikram Mehta')),
    new Department__c(Id = d.get('HR').Id, Department_Head__c = byName.get('Sara Thomas')),
    new Department__c(Id = d.get('SAL').Id, Department_Head__c = byName.get('Rohan Kapoor'))
};

// Wave 2 - managers (the running user becomes the Engineering Manager)
String me = UserInfo.getName();
List<List<Object>> managers = new List<List<Object>>{
    new List<Object>{ me, 'ENG', 'EM', 'HYD', 'Vikram Mehta', 1100, 4.3, 'Salesforce;Apex;Leadership;Agile', '1988-' + String.valueOf(Date.today().month()).leftPad(2, '0') + '-' + String.valueOf(Math.min(28, Date.today().day())).leftPad(2, '0'), 3600000 },
    new List<Object>{ 'Kiran Desai', 'ENG', 'EM', 'BLR', 'Vikram Mehta', 980, 4.0, 'Java;Architecture;Leadership;Agile', '1986-05-14', 3400000 },
    new List<Object>{ 'Meera Iyer', 'PRD', 'PM', 'BLR', 'Vikram Mehta', 820, 4.2, 'Product Strategy;Analytics;Communication', '1990-09-09', 3100000 },
    new List<Object>{ 'Arjun Nair', 'HR', 'HRBP', 'HYD', 'Sara Thomas', 760, 3.9, 'Employee Relations;Coaching;Labour Law', '1989-02-18', 2200000 },
    new List<Object>{ 'Fatima Sheikh', 'FIN', 'FA', 'HYD', 'Ananya Rao', 1300, 4.1, 'Excel;FP&A;Accounting', '1987-12-01', 2400000 },
    new List<Object>{ 'Daniel Brooks', 'SAL', 'AE', 'NYC', 'Rohan Kapoor', 640, 3.6, 'Negotiation;CRM;Prospecting', '1991-04-25', 5600000 },
    new List<Object>{ 'Lakshmi Pillai', 'CS', 'CSM', 'PUN', 'Rohan Kapoor', 700, 4.0, 'Communication;Salesforce;Renewals', '1992-06-30', 2000000 },
    new List<Object>{ 'Sameer Khan', 'IT', 'ITA', 'HYD', 'Vikram Mehta', 1000, 3.8, 'Networking;Security;Identity Management', '1990-10-10', 1800000 }
};
List<Employee__c> wave2 = new List<Employee__c>();
for (List<Object> r : managers) {
    String nm = (String) r[0];
    wave2.add(new Employee__c(Name = nm, Organization__c = org.Id, Department__c = d.get((String) r[1]).Id,
        Designation__c = g.get((String) r[2]).Id, Location__c = l.get((String) r[3]).Id, Manager__c = byName.get((String) r[4]),
        Employment_Type__c = 'Full-time', Status__c = 'Active', Date_of_Joining__c = Date.today().addDays(-(Integer) r[5]),
        Performance_Rating__c = (Decimal) r[6], Skills__c = (String) r[7], Date_of_Birth__c = Date.valueOf((String) r[8]),
        Annual_CTC__c = (Decimal) r[9], Work_Mode__c = 'Hybrid', Background_Check_Status__c = 'Cleared', Education_Verified__c = true,
        Previous_Employment_Verified__c = true, Bank_Details_Verified__c = true, Handbook_Acknowledged__c = true,
        Work_Email__c = nm.toLowerCase().replaceAll('[^a-z ]', '').replace(' ', '.') + '@nimbus.example', Phone__c = '+91 98480 1' + String.valueOf(wave2.size()).leftPad(4, '0'),
        Emergency_Contact_Name__c = 'Family contact', Emergency_Contact_Phone__c = '+91 90000 00001', Blood_Group__c = 'B+',
        Career_Aspiration__c = 'Grow into a director role and mentor first-time managers.', Succession_Readiness__c = 'Ready Now',
        User__c = nm == me ? UserInfo.getUserId() : null, Recognition_Points__c = 20));
}
insert wave2;
for (Employee__c e : wave2) byName.put(e.Name, e.Id);

// Wave 3 - individual contributors
List<List<Object>> staff = new List<List<Object>>{
    // name, dept, desig, loc, manager, joinedDaysAgo, rating, skills, status, type, ctc
    new List<Object>{ 'Priya Sharma', 'ENG', 'SSE', 'HYD', me, 900, 4.6, 'Apex;LWC;Integration;Testing', 'Active', 'Full-time', 2400000 },
    new List<Object>{ 'Rahul Verma', 'ENG', 'SE', 'HYD', me, 420, 3.8, 'Apex;Git', 'Active', 'Full-time', 1400000 },
    new List<Object>{ 'Neha Gupta', 'ENG', 'SE', 'HYD', me, 300, 4.1, 'Apex;LWC;Git;Testing', 'Active', 'Full-time', 1500000 },
    new List<Object>{ 'Aditya Singh', 'ENG', 'QA', 'HYD', me, 650, 3.4, 'Testing;Selenium', 'Active', 'Full-time', 1200000 },
    new List<Object>{ 'Sneha Reddy', 'ENG', 'SE', 'HYD', me, 120, 3.9, 'Java;Git', 'Active', 'Full-time', 1300000 },
    new List<Object>{ 'Karthik Subramanian', 'ENG', 'SSE', 'HYD', me, 1500, 2.4, 'Apex;Integration;Mulesoft', 'Active', 'Full-time', 2600000 },
    new List<Object>{ 'Ishaan Malhotra', 'ENG', 'INT', 'HYD', me, 25, null, 'Python;Git', 'Onboarding', 'Intern', 360000 },
    new List<Object>{ 'Pooja Joshi', 'ENG', 'SSE', 'BLR', 'Kiran Desai', 1100, 4.2, 'Java;Kubernetes;AWS;Testing', 'Active', 'Full-time', 2500000 },
    new List<Object>{ 'Manoj Kumar', 'ENG', 'SE', 'BLR', 'Kiran Desai', 200, 3.7, 'JavaScript;LWC;Git', 'Active', 'Full-time', 1350000 },
    new List<Object>{ 'Divya Menon', 'ENG', 'QA', 'BLR', 'Kiran Desai', 520, 4.0, 'Testing;Automation;Selenium', 'Active', 'Full-time', 1250000 },
    new List<Object>{ 'Varun Chatterjee', 'ENG', 'SE', 'PUN', 'Kiran Desai', 80, 3.5, 'Python;Data Engineering', 'Active', 'Contractor', 1600000 },
    new List<Object>{ 'Tanvi Agarwal', 'PRD', 'DES', 'BLR', 'Meera Iyer', 480, 4.4, 'Figma;UX Research;Design Systems', 'Active', 'Full-time', 1800000 },
    new List<Object>{ 'Nikhil Bose', 'PRD', 'PM', 'BLR', 'Meera Iyer', 260, 3.6, 'Analytics;Communication', 'Active', 'Full-time', 2200000 },
    new List<Object>{ 'Ritu Saxena', 'HR', 'HRE', 'HYD', 'Arjun Nair', 340, 4.0, 'Onboarding;HRIS;Communication', 'Active', 'Full-time', 700000 },
    new List<Object>{ 'Gaurav Patil', 'HR', 'HRE', 'PUN', 'Arjun Nair', 150, 3.8, 'Recruiting;Communication', 'Active', 'Full-time', 680000 },
    new List<Object>{ 'Amit Tiwari', 'FIN', 'FA', 'HYD', 'Fatima Sheikh', 560, 3.9, 'Excel;Accounting', 'Active', 'Full-time', 1100000 },
    new List<Object>{ 'Emily Carter', 'SAL', 'AE', 'NYC', 'Daniel Brooks', 400, 4.3, 'Negotiation;CRM;Prospecting', 'Active', 'Full-time', 5200000 },
    new List<Object>{ 'Jason Lee', 'SAL', 'AE', 'NYC', 'Daniel Brooks', 210, 2.8, 'Prospecting', 'Active', 'Full-time', 4800000 },
    new List<Object>{ 'Harsha Vardhan', 'SAL', 'AE', 'HYD', 'Rohan Kapoor', 610, 3.7, 'Negotiation;CRM', 'Active', 'Full-time', 1900000 },
    new List<Object>{ 'Ayesha Siddiqui', 'CS', 'CSM', 'PUN', 'Lakshmi Pillai', 380, 4.1, 'Communication;Salesforce;Renewals', 'Active', 'Full-time', 1400000 },
    new List<Object>{ 'Suresh Babu', 'CS', 'CSM', 'PUN', 'Lakshmi Pillai', 900, 3.2, 'Communication;Renewals', 'On Notice', 'Full-time', 1500000 },
    new List<Object>{ 'Kavya Krishnan', 'IT', 'ITA', 'HYD', 'Sameer Khan', 290, 3.9, 'Networking;Security', 'Active', 'Full-time', 1100000 },
    new List<Object>{ 'Zoya Ahmed', 'ENG', 'SE', 'HYD', me, -10, null, 'Apex;LWC', 'Pre-boarding', 'Full-time', 1450000 },
    new List<Object>{ 'Leo Fernandes', 'CS', 'CSM', 'PUN', 'Lakshmi Pillai', -5, null, 'Salesforce;Communication', 'Pre-boarding', 'Full-time', 1300000 }
};
List<Employee__c> wave3 = new List<Employee__c>();
Integer i = 0;
for (List<Object> r : staff) {
    String nm = (String) r[0];
    Integer joined = (Integer) r[5];
    Boolean complete = Math.mod(i, 3) != 0;
    wave3.add(new Employee__c(Name = nm, Organization__c = org.Id, Department__c = d.get((String) r[1]).Id,
        Designation__c = g.get((String) r[2]).Id, Location__c = l.get((String) r[3]).Id, Manager__c = byName.get((String) r[4]),
        Date_of_Joining__c = Date.today().addDays(-joined), Performance_Rating__c = (Decimal) r[6], Skills__c = (String) r[7],
        Status__c = (String) r[8], Employment_Type__c = (String) r[9], Annual_CTC__c = (Decimal) r[10],
        Work_Mode__c = Math.mod(i, 4) == 0 ? 'Remote' : (Math.mod(i, 2) == 0 ? 'Office' : 'Hybrid'),
        Work_Email__c = nm.toLowerCase().replace(' ', '.') + '@nimbus.example', Phone__c = '+91 99590 2' + String.valueOf(i).leftPad(4, '0'),
        Date_of_Birth__c = Date.newInstance(1990 + Math.mod(i, 8), Math.mod(i * 5, 12) + 1, Math.mod(i * 7, 27) + 1),
        Gender__c = Math.mod(i, 2) == 0 ? 'Female' : 'Male', Blood_Group__c = Math.mod(i, 2) == 0 ? 'A+' : 'O+',
        Background_Check_Status__c = joined < 0 ? 'In Progress' : 'Cleared', Education_Verified__c = complete,
        Previous_Employment_Verified__c = complete, Bank_Details_Verified__c = joined > 0, Handbook_Acknowledged__c = complete && joined > 0,
        Emergency_Contact_Name__c = complete ? 'Family contact' : null, Emergency_Contact_Phone__c = complete ? '+91 90000 00002' : null,
        Recognition_Points__c = Math.mod(i, 5) == 0 ? 0 : Math.mod(i, 4) * 10,
        Career_Aspiration__c = Math.mod(i, 3) == 0 ? 'Move into a tech lead role within two years.' : null));
    i++;
}
insert wave3;

// Past leavers for attrition analytics (spread over the last 12 months)
List<Employee__c> leavers = new List<Employee__c>();
List<String> leaverDepts = new List<String>{ 'SAL', 'ENG', 'CS', 'SAL', 'ENG', 'PRD' };
List<String> leaverNames = new List<String>{ 'Mark Wilson', 'Deepak Rao', 'Anita Das', 'Chris Evans', 'Farhan Ali', 'Nisha Jain' };
for (Integer k = 0; k < leaverNames.size(); k++) {
    leavers.add(new Employee__c(Name = leaverNames[k], Organization__c = org.Id, Department__c = d.get(leaverDepts[k]).Id,
        Location__c = l.get('HYD').Id, Status__c = 'Exited', Employment_Type__c = 'Full-time', Rehire_Eligible__c = Math.mod(k, 2) == 0,
        Date_of_Joining__c = Date.today().addDays(-900 - k * 60), Exit_Date__c = Date.today().addDays(-20 - k * 50),
        Work_Email__c = leaverNames[k].toLowerCase().replace(' ', '.') + '@nimbus.example', Annual_CTC__c = 1500000));
}
insert leavers;

System.debug('Seed part 1 complete: ' + [SELECT COUNT() FROM Employee__c] + ' employees.');
