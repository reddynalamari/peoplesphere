// Links the PeopleSphere site guest user to a demo employee ("Alex Demo") and grants the guest gateway.
// Run after the Experience Cloud site exists:
//   sf apex run --file scripts/apex/setup_public_demo.apex --target-org <alias>
Id guestId = [SELECT GuestUserId FROM Site WHERE Name = 'PeopleSphere' LIMIT 1].GuestUserId;
// The guest permission set is assigned separately (setup and data DML cannot mix):
//   sf data create record -s PermissionSetAssignment -v "AssigneeId=<guest user id> PermissionSetId=<PeopleSphere_Guest_Demo id>"

if ([SELECT COUNT() FROM Employee__c WHERE User__c = :guestId] == 0) {
    Employee__c mgr = [SELECT Id, Organization__c, Department__c, Location__c FROM Employee__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
    Id desig = [SELECT Id FROM Designation__c WHERE Name = 'Software Engineer' LIMIT 1].Id;
    Employee__c demo = new Employee__c(Name = 'Alex Demo', First_Name__c = 'Alex', Last_Name__c = 'Demo', User__c = guestId,
        Organization__c = mgr.Organization__c, Department__c = mgr.Department__c, Location__c = mgr.Location__c, Designation__c = desig,
        Manager__c = mgr.Id, Status__c = 'Active', Employment_Type__c = 'Full-time', Work_Mode__c = 'Hybrid',
        Date_of_Joining__c = Date.today().addDays(-410), Date_of_Birth__c = Date.newInstance(1996, 8, 14), Gender__c = 'Prefer not to say',
        Work_Email__c = 'alex.demo@nimbus.example', Phone__c = '+91 90000 12345', Skills__c = 'Apex;Git;JavaScript',
        Career_Aspiration__c = 'Become a Salesforce architect.', Performance_Rating__c = 3.8, Recognition_Points__c = 30,
        Background_Check_Status__c = 'Cleared', Education_Verified__c = true, Previous_Employment_Verified__c = true, Bank_Details_Verified__c = true,
        Emergency_Contact_Name__c = 'Sam Demo', Emergency_Contact_Phone__c = '+91 90000 54321', Blood_Group__c = 'O+');
    insert demo;

    Date d = Date.today().addDays(-1);
    List<Attendance__c> att = new List<Attendance__c>();
    Integer k = 0;
    while (att.size() < 8) {
        if (!PS_Util.isWeekend(d)) {
            Datetime cin = Datetime.newInstance(d, Time.newInstance(9, 10 + Math.mod(k * 13, 40), 0, 0));
            att.add(new Attendance__c(Employee__c = demo.Id, Attendance_Date__c = d, Status__c = Math.mod(k, 4) == 3 ? 'Work From Home' : 'Present',
                Check_In__c = cin, Check_Out__c = cin.addHours(9), Work_Mode__c = Math.mod(k, 4) == 3 ? 'Remote' : 'Office'));
            k++;
        }
        d = d.addDays(-1);
    }
    insert att;

    Date pastDay = Date.today().addDays(-40);
    while (PS_Util.isWeekend(pastDay)) pastDay = pastDay.addDays(-1);
    Leave_Request__c past = new Leave_Request__c(Employee__c = demo.Id, Leave_Type__c = 'Casual Leave', Start_Date__c = pastDay, End_Date__c = pastDay, Reason__c = 'Personal errand');
    insert past;
    past.Status__c = 'Approved';
    update past;

    Id engGoal = [SELECT Id FROM Goal__c WHERE Name = 'Ship Platform v3' LIMIT 1].Id;
    insert new List<Goal__c>{
        new Goal__c(Name = 'Earn Platform Developer I', Employee__c = demo.Id, Goal_Type__c = 'Individual', Framework__c = 'SMART', Key_Result__c = 'Certification passed', Target_Value__c = 1, Current_Value__c = 0, Unit__c = 'cert', Status__c = 'On Track', Due_Date__c = Date.today().addDays(60)),
        new Goal__c(Name = 'Close 15 platform stories', Employee__c = demo.Id, Parent_Goal__c = engGoal, Goal_Type__c = 'Individual', Framework__c = 'OKR', Key_Result__c = 'Stories delivered', Target_Value__c = 15, Current_Value__c = 9, Unit__c = 'stories', Status__c = 'On Track', Due_Date__c = Date.today().addDays(40))
    };
    insert new Performance_Review__c(Employee__c = demo.Id, Reviewer__c = mgr.Id, Review_Cycle__c = 'Mid-Year', Status__c = 'Self Assessment', Due_Date__c = Date.today().addDays(14));
    insert new Company_Asset__c(Name = 'MacBook Pro 14"', Asset_Tag__c = 'NIM-LT-DEMO', Asset_Type__c = 'Laptop', Assigned_To__c = demo.Id, Condition__c = 'Good');
    insert new HR_Ticket__c(Employee__c = demo.Id, Subject__c = 'How do I claim internet allowance?', Description__c = 'I work from home two days a week. How can I claim my internet bill?', Channel__c = 'Portal');
    insert new Recognition__c(Giver__c = mgr.Id, Recipient__c = demo.Id, Badge__c = 'Team Player', Points__c = 10, Message__c = 'Thanks for covering the release on-call, Alex!');
    // complete one mandatory course so the profile shows a certification; leave the rest open for the quiz
    List<Learning_Enrollment__c> enr = [SELECT Id FROM Learning_Enrollment__c WHERE Employee__c = :demo.Id AND Course__r.Course_Code__c = 'CMP-102'];
    if (!enr.isEmpty()) { enr[0].Status__c = 'Completed'; enr[0].Score__c = 90; update enr; }
    insert new Learning_Enrollment__c(Employee__c = demo.Id, Course__c = [SELECT Id FROM Learning_Course__c WHERE Course_Code__c = 'TEC-201'].Id, Status__c = 'In Progress', Progress_Percent__c = 30, Due_Date__c = Date.today().addDays(20), Assignment_Source__c = 'Skill Gap');
}
System.debug('Public demo ready for guest user ' + guestId);
