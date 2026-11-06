/**
 * Employee 360 / "digital twin": one call that assembles the complete
 * employee journey - profile, lifecycle stage, timeline, learning,
 * performance, documents, assets, leave and operational risk indicators.
 */
public inherited sharing class PS_Employee360Controller {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchEmployees(String term) {
        try {
            List<Map<String, Object>> out = new List<Map<String, Object>>();
            if (String.isBlank(term) || term.trim().length() < 2) return out;
            String pattern = '%' + String.escapeSingleQuotes(term.trim()) + '%';
            for (Employee__c e : [
                SELECT Id, Name, Employee_ID__c, Designation__r.Name, Department__r.Name, Status__c, Photo_URL__c, Work_Email__c
                FROM Employee__c
                WHERE Name LIKE :pattern OR Employee_ID__c LIKE :pattern OR Work_Email__c LIKE :pattern OR Department__r.Name LIKE :pattern
                ORDER BY Name LIMIT 15
            ]) {
                out.add(new Map<String, Object>{ 'id' => e.Id, 'name' => e.Name, 'employeeId' => e.Employee_ID__c,
                    'designation' => e.Designation__r?.Name, 'department' => e.Department__r?.Name, 'status' => e.Status__c,
                    'photo' => e.Photo_URL__c, 'email' => e.Work_Email__c });
            }
            return out;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getEmployee360(Id employeeId) {
        try {
            if (employeeId == null) {
                Employee__c me = PS_Util.currentEmployee();
                if (me == null) return null;
                employeeId = me.Id;
            }
            Employee__c e = [
                SELECT Id, Name, Employee_ID__c, First_Name__c, Last_Name__c, Work_Email__c, Phone__c, Photo_URL__c, Status__c,
                       Employment_Type__c, Work_Mode__c, Date_of_Joining__c, Date_of_Birth__c, Exit_Date__c, Tenure_Years__c,
                       Skills__c, Career_Aspiration__c, Profile_Completeness__c, Performance_Rating__c, Attrition_Risk__c,
                       Critical_Role__c, Succession_Readiness__c, Recognition_Points__c, Annual_CTC__c, Background_Check_Status__c,
                       Casual_Leave_Balance__c, Sick_Leave_Balance__c, Earned_Leave_Balance__c,
                       Organization__r.Name, Department__r.Name, Designation__r.Name, Designation__r.Grade__c,
                       Designation__r.Required_Skills__c, Location__r.Name, Manager__c, Manager__r.Name,
                       Manager__r.Designation__r.Name, Manager__r.Photo_URL__c, User__c
                FROM Employee__c WHERE Id = :employeeId];

            Map<String, Object> out = new Map<String, Object>();
            Boolean canSeeRisk = PS_Util.canSee(Schema.SObjectType.Employee__c.fields.Attrition_Risk__c);
            out.put('employee', new Map<String, Object>{
                'id' => e.Id, 'name' => e.Name, 'employeeId' => e.Employee_ID__c, 'email' => e.Work_Email__c, 'phone' => e.Phone__c,
                'photo' => e.Photo_URL__c, 'status' => e.Status__c, 'type' => e.Employment_Type__c, 'workMode' => e.Work_Mode__c,
                'joined' => e.Date_of_Joining__c, 'exitDate' => e.Exit_Date__c, 'tenure' => e.Tenure_Years__c,
                'organization' => e.Organization__r?.Name, 'department' => e.Department__r?.Name,
                'designation' => e.Designation__r?.Name, 'grade' => e.Designation__r?.Grade__c, 'location' => e.Location__r?.Name,
                'managerId' => e.Manager__c, 'manager' => e.Manager__r?.Name, 'managerTitle' => e.Manager__r?.Designation__r?.Name,
                'completeness' => e.Profile_Completeness__c, 'rating' => e.Performance_Rating__c,
                'risk' => canSeeRisk ? e.Attrition_Risk__c : null,
                'ctc' => PS_Util.canSee(Schema.SObjectType.Employee__c.fields.Annual_CTC__c) ? e.Annual_CTC__c : null, 'critical' => e.Critical_Role__c,
                'succession' => e.Succession_Readiness__c, 'points' => e.Recognition_Points__c,
                'aspiration' => e.Career_Aspiration__c, 'backgroundCheck' => e.Background_Check_Status__c,
                'casual' => e.Casual_Leave_Balance__c, 'sick' => e.Sick_Leave_Balance__c, 'earned' => e.Earned_Leave_Balance__c
            });

            // skills + skill gap against designation
            Set<String> have = PS_Util.splitSkills(e.Skills__c);
            List<Map<String, Object>> skills = new List<Map<String, Object>>();
            for (String s : have) skills.add(new Map<String, Object>{ 'name' => s, 'gap' => false });
            for (String s : PS_Util.splitSkills(e.Designation__r?.Required_Skills__c)) {
                if (!have.contains(s)) skills.add(new Map<String, Object>{ 'name' => s, 'gap' => true });
            }
            out.put('skills', skills);

            List<Map<String, Object>> reports = new List<Map<String, Object>>();
            for (Employee__c r : [SELECT Id, Name, Designation__r.Name, Status__c, Photo_URL__c FROM Employee__c
                                  WHERE Manager__c = :e.Id AND Status__c IN :PS_Util.ACTIVE_STATUSES ORDER BY Name LIMIT 50]) {
                reports.add(new Map<String, Object>{ 'id' => r.Id, 'name' => r.Name, 'designation' => r.Designation__r?.Name, 'status' => r.Status__c, 'photo' => r.Photo_URL__c });
            }
            out.put('directReports', reports);

            // ---- related records ----------------------------------------
            List<Onboarding__c> onb = [SELECT Id, Name, Status__c, Completion_Percent__c, Start_Date__c, Completed_On__c, Total_Tasks__c, Completed_Tasks__c
                                       FROM Onboarding__c WHERE Employee__c = :e.Id ORDER BY CreatedDate DESC LIMIT 1];
            out.put('onboarding', onb.isEmpty() ? null : onb[0]);
            List<Learning_Enrollment__c> enr = [SELECT Id, Course__r.Name, Course__r.Category__c, Course__r.Mandatory__c, Status__c, Progress_Percent__c,
                                                       Due_Date__c, Completion_Date__c, Score__c, Is_Overdue__c, Assignment_Source__c
                                                FROM Learning_Enrollment__c WHERE Employee__c = :e.Id ORDER BY Due_Date__c DESC NULLS LAST LIMIT 50];
            out.put('enrollments', enr);
            List<Certification__c> certs = [SELECT Id, Name, Issued_On__c, Expires_On__c, Status__c, Certificate_Number__c FROM Certification__c WHERE Employee__c = :e.Id ORDER BY Issued_On__c DESC LIMIT 30];
            out.put('certifications', certs);
            List<Performance_Review__c> reviews = [SELECT Id, Name, Review_Cycle__c, Review_Year__c, Status__c, Self_Rating__c, Manager_Rating__c, Final_Rating__c,
                                                          Due_Date__c, Completed_On__c, Is_Overdue__c, Reviewer__r.Name, Promotion_Recommended__c
                                                   FROM Performance_Review__c WHERE Employee__c = :e.Id ORDER BY CreatedDate DESC LIMIT 20];
            out.put('reviews', reviews);
            out.put('goals', [SELECT Id, Name, Goal_Type__c, Framework__c, Status__c, Progress__c, Due_Date__c, Parent_Goal__r.Name, Weightage__c
                              FROM Goal__c WHERE Employee__c = :e.Id ORDER BY Due_Date__c NULLS LAST LIMIT 30]);
            List<Employee_Document__c> docs = [SELECT Id, Name, Document_Type__c, Verification_Status__c, Expiry_Date__c, Days_To_Expiry__c, Mandatory__c
                                               FROM Employee_Document__c WHERE Employee__c = :e.Id ORDER BY Mandatory__c DESC, Name LIMIT 50];
            out.put('documents', docs);
            out.put('assets', [SELECT Id, Name, Asset_Tag__c, Asset_Type__c, Status__c, Assigned_On__c FROM Company_Asset__c WHERE Assigned_To__c = :e.Id ORDER BY Assigned_On__c DESC LIMIT 20]);
            out.put('leaves', [SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c, Number_of_Days__c, Status__c FROM Leave_Request__c WHERE Employee__c = :e.Id ORDER BY Start_Date__c DESC LIMIT 10]);
            out.put('openTickets', [SELECT COUNT() FROM HR_Ticket__c WHERE Employee__c = :e.Id AND Status__c NOT IN ('Resolved', 'Closed')]);
            List<Exit_Process__c> exits = [SELECT Id, Name, Status__c, Last_Working_Day__c, Clearance_Percent__c, Exit_Type__c FROM Exit_Process__c WHERE Employee__c = :e.Id ORDER BY CreatedDate DESC LIMIT 1];
            out.put('exitProcess', exits.isEmpty() ? null : exits[0]);

            // ---- KPIs -----------------------------------------------------
            Integer mand = 0, mandDone = 0;
            for (Learning_Enrollment__c le : enr) {
                if (le.Course__r.Mandatory__c && le.Status__c != 'Waived') { mand++; if (le.Status__c == 'Completed') mandDone++; }
            }
            out.put('trainingCompliance', mand == 0 ? 100 : Math.round(mandDone * 100.0 / mand));

            out.put('lifecycle', lifecycle(e, onb.isEmpty() ? null : onb[0], enr, reviews, exits.isEmpty() ? null : exits[0]));
            out.put('timeline', timeline(e.Id));
            out.put('risks', risks(e, enr, certs, reviews, docs));
            return out;
        } catch (Exception ex) {
            throw PS_Util.auraError(ex);
        }
    }

    private static List<Map<String, Object>> lifecycle(Employee__c e, Onboarding__c onb, List<Learning_Enrollment__c> enr,
                                                       List<Performance_Review__c> reviews, Exit_Process__c exitP) {
        Boolean exited = e.Status__c == 'Exited' || e.Status__c == 'Alumni';
        Boolean anyLearning = !enr.isEmpty();
        Boolean anyReview = !reviews.isEmpty();
        List<Map<String, Object>> stages = new List<Map<String, Object>>();
        stages.add(stage('Recruitment', 'Offer accepted and pre-boarding', 'complete'));
        stages.add(stage('Onboarding', onb == null ? 'Not started' : onb.Status__c + ' - ' + (onb.Completion_Percent__c == null ? 0 : onb.Completion_Percent__c.setScale(0)) + '%',
            onb != null && onb.Status__c == 'Completed' ? 'complete' : (e.Status__c == 'Pre-boarding' || e.Status__c == 'Onboarding' ? 'current' : (onb == null ? 'upcoming' : 'current'))));
        stages.add(stage('Learning', anyLearning ? enr.size() + ' course(s) assigned' : 'No courses yet',
            exited ? 'complete' : (anyLearning ? 'current' : 'upcoming')));
        stages.add(stage('Performance', anyReview ? reviews.size() + ' review(s)' : 'Awaiting first review',
            exited ? 'complete' : (anyReview ? 'current' : 'upcoming')));
        stages.add(stage('Career growth', e.Succession_Readiness__c == null ? 'Skills and internal mobility' : 'Succession: ' + e.Succession_Readiness__c,
            exited ? 'complete' : (e.Status__c == 'Active' ? 'current' : 'upcoming')));
        stages.add(stage('Offboarding', exitP == null ? 'Future stage' : exitP.Status__c,
            exited ? 'complete' : (exitP != null ? 'current' : 'upcoming')));
        return stages;
    }

    private static Map<String, Object> stage(String name, String detail, String state) {
        return new Map<String, Object>{ 'name' => name, 'detail' => detail, 'state' => state };
    }

    /** Unified timeline across every module, newest first. */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> timeline(Id employeeId) {
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        for (Employment_History__c h : [SELECT Event_Type__c, Effective_Date__c, Previous_Value__c, New_Value__c, Field_Changed__c, Notes__c, CreatedDate
                                        FROM Employment_History__c WHERE Employee__c = :employeeId ORDER BY CreatedDate DESC LIMIT 50]) {
            String detail = h.Notes__c;
            if (h.Field_Changed__c != null) detail = h.Field_Changed__c + ': ' + (h.Previous_Value__c == null ? '-' : h.Previous_Value__c) + ' → ' + (h.New_Value__c == null ? '-' : h.New_Value__c);
            items.add(item(h.CreatedDate, h.Event_Type__c, detail, 'utility:change_owner', 'history'));
        }
        for (Learning_Enrollment__c le : [SELECT Course__r.Name, Completion_Date__c, LastModifiedDate, Score__c FROM Learning_Enrollment__c
                                          WHERE Employee__c = :employeeId AND Status__c = 'Completed' ORDER BY LastModifiedDate DESC LIMIT 20]) {
            items.add(item(le.LastModifiedDate, 'Course completed', le.Course__r.Name + (le.Score__c == null ? '' : ' (score ' + le.Score__c + '%)'), 'utility:education', 'learning'));
        }
        for (Certification__c c : [SELECT Name, CreatedDate, Expires_On__c FROM Certification__c WHERE Employee__c = :employeeId ORDER BY CreatedDate DESC LIMIT 20]) {
            items.add(item(c.CreatedDate, 'Certification earned', c.Name + (c.Expires_On__c == null ? '' : ' - valid until ' + c.Expires_On__c.format()), 'utility:ribbon', 'learning'));
        }
        for (Performance_Review__c r : [SELECT Review_Cycle__c, Review_Year__c, Final_Rating__c, LastModifiedDate FROM Performance_Review__c
                                        WHERE Employee__c = :employeeId AND Status__c = 'Completed' ORDER BY LastModifiedDate DESC LIMIT 10]) {
            items.add(item(r.LastModifiedDate, 'Performance review', r.Review_Cycle__c + ' ' + r.Review_Year__c + ' - rated ' + r.Final_Rating__c, 'utility:favorite', 'performance'));
        }
        for (Recognition__c r : [SELECT Badge__c, Message__c, Giver__r.Name, CreatedDate FROM Recognition__c WHERE Recipient__c = :employeeId ORDER BY CreatedDate DESC LIMIT 10]) {
            items.add(item(r.CreatedDate, 'Recognized: ' + r.Badge__c, 'From ' + r.Giver__r?.Name + (r.Message__c == null ? '' : ' - "' + r.Message__c.abbreviate(120) + '"'), 'utility:like', 'engagement'));
        }
        for (Onboarding__c o : [SELECT Name, CreatedDate, Status__c, Completed_On__c FROM Onboarding__c WHERE Employee__c = :employeeId LIMIT 5]) {
            items.add(item(o.CreatedDate, 'Onboarding started', o.Name + ' (' + o.Status__c + ')', 'utility:flow', 'onboarding'));
        }
        for (Exit_Process__c x : [SELECT Name, CreatedDate, Exit_Type__c, Last_Working_Day__c FROM Exit_Process__c WHERE Employee__c = :employeeId LIMIT 5]) {
            items.add(item(x.CreatedDate, 'Exit initiated', x.Exit_Type__c + ' - last working day ' + x.Last_Working_Day__c?.format(), 'utility:logout', 'exit'));
        }
        // newest first
        for (Integer i = 0; i < items.size(); i++) {
            for (Integer j = i + 1; j < items.size(); j++) {
                if (((Datetime) items[j].get('when')) > ((Datetime) items[i].get('when'))) {
                    Map<String, Object> t = items[i]; items[i] = items[j]; items[j] = t;
                }
            }
        }
        while (items.size() > 40) items.remove(items.size() - 1);
        return items;
    }

    private static Map<String, Object> item(Datetime whenAt, String title, String detail, String icon, String kind) {
        return new Map<String, Object>{ 'when' => whenAt, 'title' => title, 'detail' => detail, 'icon' => icon, 'kind' => kind };
    }

    private static List<Map<String, Object>> risks(Employee__c e, List<Learning_Enrollment__c> enr, List<Certification__c> certs,
                                                   List<Performance_Review__c> reviews, List<Employee_Document__c> docs) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        Integer overdue = 0;
        for (Learning_Enrollment__c le : enr) if (le.Is_Overdue__c || le.Status__c == 'Overdue') overdue++;
        if (overdue > 0) out.add(risk('warning', overdue + ' overdue training assignment(s)'));
        for (Certification__c c : certs) {
            if (c.Status__c == 'Expired') out.add(risk('error', 'Certification expired: ' + c.Name));
            else if (c.Status__c == 'Expiring Soon') out.add(risk('warning', 'Certification expiring soon: ' + c.Name));
        }
        for (Performance_Review__c r : reviews) if (r.Is_Overdue__c) out.add(risk('warning', 'Overdue review: ' + r.Review_Cycle__c + ' ' + r.Review_Year__c));
        Integer missing = 0;
        for (Employee_Document__c d : docs) {
            if (d.Mandatory__c && (d.Verification_Status__c == 'Pending Upload' || d.Verification_Status__c == 'Rejected')) missing++;
            if (d.Verification_Status__c == 'Expired') out.add(risk('error', 'Document expired: ' + d.Name));
        }
        if (missing > 0) out.add(risk('warning', missing + ' mandatory document(s) missing'));
        if (e.Background_Check_Status__c == 'Flagged') out.add(risk('error', 'Background check flagged'));
        if (e.Profile_Completeness__c != null && e.Profile_Completeness__c < 60) out.add(risk('info', 'Profile only ' + e.Profile_Completeness__c + '% complete'));
        if (e.Critical_Role__c && (e.Succession_Readiness__c == null || e.Succession_Readiness__c == 'Not Identified')) out.add(risk('warning', 'Critical role without an identified successor'));
        return out;
    }

    private static Map<String, Object> risk(String level, String text) {
        return new Map<String, Object>{ 'level' => level, 'text' => text };
    }
}
