/**
 * Learning management: mandatory/role-based assignment, prerequisite
 * enforcement, server-side quiz grading, certification issuing and
 * skill-gap-based course recommendations.
 */
public without sharing class PS_LearningService {

    /** Assigns active mandatory courses for each employee's department (or company-wide). */
    public static void assignMandatory(Set<Id> employeeIds, String source) {
        List<Learning_Course__c> courses = [
            SELECT Id, Target_Department__c, Due_In_Days__c FROM Learning_Course__c WHERE Mandatory__c = true AND Active__c = true
        ];
        if (courses.isEmpty() || employeeIds.isEmpty()) return;
        List<Employee__c> emps = [
            SELECT Id, Department__c, (SELECT Course__c FROM Enrollments__r)
            FROM Employee__c WHERE Id IN :employeeIds AND Status__c IN :PS_Util.ACTIVE_STATUSES
        ];
        List<Learning_Enrollment__c> toInsert = new List<Learning_Enrollment__c>();
        for (Employee__c e : emps) {
            Set<Id> have = new Set<Id>();
            for (Learning_Enrollment__c le : e.Enrollments__r) have.add(le.Course__c);
            for (Learning_Course__c c : courses) {
                if (have.contains(c.Id)) continue;
                if (c.Target_Department__c != null && c.Target_Department__c != e.Department__c) continue;
                toInsert.add(newEnrollment(e.Id, c, source));
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    /** Course trigger: newly mandatory courses are pushed to every eligible employee. */
    public static void afterCourseSave(List<Learning_Course__c> rows, Map<Id, Learning_Course__c> oldMap) {
        Boolean found = false;
        for (Learning_Course__c c : rows) {
            Boolean wasMandatory = oldMap != null && oldMap.get(c.Id).Mandatory__c && oldMap.get(c.Id).Active__c;
            if (c.Mandatory__c && c.Active__c && !wasMandatory) found = true;
        }
        if (!found) return;
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id FROM Employee__c WHERE Status__c IN :PS_Util.ACTIVE_STATUSES LIMIT 5000]);
        assignMandatory(emps.keySet(), 'Mandatory Rule');
    }

    public static Learning_Enrollment__c newEnrollment(Id employeeId, Learning_Course__c c, String source) {
        Integer dueIn = c.Due_In_Days__c == null ? 30 : c.Due_In_Days__c.intValue();
        return new Learning_Enrollment__c(Employee__c = employeeId, Course__c = c.Id, Status__c = 'Assigned',
            Assigned_On__c = Date.today(), Due_Date__c = Date.today().addDays(dueIn), Assignment_Source__c = source, Progress_Percent__c = 0);
    }

    public static Learning_Enrollment__c enroll(Id employeeId, Id courseId, String source) {
        Learning_Course__c c = [SELECT Id, Name, Due_In_Days__c, Active__c, Prerequisite_Course__c, Prerequisite_Course__r.Name
                                FROM Learning_Course__c WHERE Id = :courseId];
        if (!c.Active__c) throw new PS_Util.PS_Exception('This course is not active.');
        if ([SELECT COUNT() FROM Learning_Enrollment__c WHERE Employee__c = :employeeId AND Course__c = :courseId AND Status__c != 'Waived'] > 0) {
            throw new PS_Util.PS_Exception('You are already enrolled in ' + c.Name + '.');
        }
        if (c.Prerequisite_Course__c != null && [
                SELECT COUNT() FROM Learning_Enrollment__c
                WHERE Employee__c = :employeeId AND Course__c = :c.Prerequisite_Course__c AND Status__c = 'Completed'] == 0) {
            throw new PS_Util.PS_Exception('Complete the prerequisite course "' + c.Prerequisite_Course__r.Name + '" first.');
        }
        Learning_Enrollment__c le = newEnrollment(employeeId, c, source);
        insert le;
        return le;
    }

    public static void beforeEnrollmentSave(List<Learning_Enrollment__c> rows, Map<Id, Learning_Enrollment__c> oldMap) {
        for (Learning_Enrollment__c le : rows) {
            if (le.Assigned_On__c == null) le.Assigned_On__c = Date.today();
            Boolean wasDone = oldMap != null && oldMap.get(le.Id).Status__c == 'Completed';
            if (le.Status__c == 'Completed' && !wasDone) {
                le.Completion_Date__c = Date.today();
                le.Progress_Percent__c = 100;
            }
            if (le.Status__c == 'Assigned' && le.Progress_Percent__c != null && le.Progress_Percent__c > 0) le.Status__c = 'In Progress';
        }
    }

    /** Issues a certification when a course with a validity period is completed. */
    public static void afterEnrollmentSave(List<Learning_Enrollment__c> rows, Map<Id, Learning_Enrollment__c> oldMap) {
        Set<Id> courseIds = new Set<Id>();
        List<Learning_Enrollment__c> completed = new List<Learning_Enrollment__c>();
        for (Learning_Enrollment__c le : rows) {
            Boolean wasDone = oldMap != null && oldMap.get(le.Id).Status__c == 'Completed';
            if (le.Status__c == 'Completed' && !wasDone) {
                completed.add(le);
                courseIds.add(le.Course__c);
            }
        }
        if (completed.isEmpty()) return;
        Map<Id, Learning_Course__c> courses = new Map<Id, Learning_Course__c>([
            SELECT Id, Name, Certification_Validity_Months__c, Course_Code__c FROM Learning_Course__c WHERE Id IN :courseIds]);
        List<Certification__c> certs = new List<Certification__c>();
        for (Learning_Enrollment__c le : completed) {
            Learning_Course__c c = courses.get(le.Course__c);
            if (c == null || c.Certification_Validity_Months__c == null || c.Certification_Validity_Months__c <= 0) continue;
            certs.add(new Certification__c(Name = (c.Name + ' Certificate').abbreviate(80), Employee__c = le.Employee__c, Course__c = c.Id,
                Issued_On__c = Date.today(), Expires_On__c = Date.today().addMonths(c.Certification_Validity_Months__c.intValue()),
                Issuing_Authority__c = 'PeopleSphere Academy',
                Certificate_Number__c = (c.Course_Code__c == null ? 'CERT' : c.Course_Code__c) + '-' + PS_Util.dateKey(Date.today()) + '-' + String.valueOf(Crypto.getRandomInteger()).right(4)));
        }
        if (!certs.isEmpty()) insert certs;
    }

    // ---------------- Quiz engine --------------------------------------
    public class QuizQuestion {
        @AuraEnabled public Id id;
        @AuraEnabled public String question;
        @AuraEnabled public List<Map<String, String>> options;
        @AuraEnabled public Decimal points;
    }
    public class Quiz {
        @AuraEnabled public Id enrollmentId;
        @AuraEnabled public String courseName;
        @AuraEnabled public String contentUrl;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal passingScore;
        @AuraEnabled public Decimal attempts;
        @AuraEnabled public String status;
        @AuraEnabled public List<QuizQuestion> questions;
    }
    public class QuizResult {
        @AuraEnabled public Decimal score;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public Decimal passingScore;
        @AuraEnabled public List<Map<String, Object>> review;
        @AuraEnabled public Boolean certificateIssued;
    }

    /** Questions for an enrollment WITHOUT correct answers - grading happens server side. */
    public static Quiz getQuiz(Id enrollmentId) {
        Learning_Enrollment__c le = loadOwnEnrollment(enrollmentId);
        Quiz q = new Quiz();
        q.enrollmentId = le.Id;
        q.courseName = le.Course__r.Name;
        q.contentUrl = le.Course__r.Content_URL__c;
        q.description = le.Course__r.Description__c;
        q.passingScore = le.Course__r.Passing_Score__c == null ? 70 : le.Course__r.Passing_Score__c;
        q.attempts = le.Attempts__c;
        q.status = le.Status__c;
        q.questions = new List<QuizQuestion>();
        for (Quiz_Question__c qq : [
            SELECT Id, Question__c, Option_A__c, Option_B__c, Option_C__c, Option_D__c, Points__c
            FROM Quiz_Question__c WHERE Course__c = :le.Course__c ORDER BY Sequence__c NULLS LAST, Name
        ]) {
            QuizQuestion x = new QuizQuestion();
            x.id = qq.Id;
            x.question = qq.Question__c;
            x.points = qq.Points__c == null ? 1 : qq.Points__c;
            x.options = new List<Map<String, String>>();
            for (String k : new List<String>{ 'A', 'B', 'C', 'D' }) {
                String label = (String) qq.get('Option_' + k + '__c');
                if (String.isNotBlank(label)) x.options.add(new Map<String, String>{ 'label' => label, 'value' => k });
            }
            q.questions.add(x);
        }
        if (le.Status__c == 'Assigned') {
            update new Learning_Enrollment__c(Id = le.Id, Status__c = 'In Progress', Progress_Percent__c = 10);
        }
        return q;
    }

    public static QuizResult submitQuiz(Id enrollmentId, Map<String, String> answers) {
        Learning_Enrollment__c le = loadOwnEnrollment(enrollmentId);
        if (le.Status__c == 'Completed') throw new PS_Util.PS_Exception('You have already passed this course.');
        Decimal total = 0, earned = 0;
        QuizResult r = new QuizResult();
        r.review = new List<Map<String, Object>>();
        for (Quiz_Question__c qq : [
            SELECT Id, Question__c, Correct_Option__c, Points__c, Explanation__c
            FROM Quiz_Question__c WHERE Course__c = :le.Course__c ORDER BY Sequence__c NULLS LAST, Name
        ]) {
            Decimal pts = qq.Points__c == null ? 1 : qq.Points__c;
            total += pts;
            String given = answers == null ? null : answers.get(qq.Id);
            Boolean ok = given != null && given == qq.Correct_Option__c;
            if (ok) earned += pts;
            r.review.add(new Map<String, Object>{
                'id' => qq.Id, 'question' => qq.Question__c, 'correct' => ok,
                'correctOption' => qq.Correct_Option__c, 'given' => given, 'explanation' => qq.Explanation__c });
        }
        r.passingScore = le.Course__r.Passing_Score__c == null ? 70 : le.Course__r.Passing_Score__c;
        r.score = total == 0 ? 100 : (earned * 100 / total).setScale(1);
        r.passed = r.score >= r.passingScore;
        r.certificateIssued = r.passed && le.Course__r.Certification_Validity_Months__c != null && le.Course__r.Certification_Validity_Months__c > 0;
        update new Learning_Enrollment__c(Id = le.Id, Score__c = r.score,
            Attempts__c = (le.Attempts__c == null ? 0 : le.Attempts__c) + 1,
            Status__c = r.passed ? 'Completed' : 'Failed', Progress_Percent__c = r.passed ? 100 : 60);
        return r;
    }

    private static Learning_Enrollment__c loadOwnEnrollment(Id enrollmentId) {
        Learning_Enrollment__c le = [
            SELECT Id, Employee__c, Employee__r.User__c, Status__c, Attempts__c, Course__c, Course__r.Name, Course__r.Content_URL__c,
                   Course__r.Description__c, Course__r.Passing_Score__c, Course__r.Certification_Validity_Months__c
            FROM Learning_Enrollment__c WHERE Id = :enrollmentId];
        if (le.Employee__r.User__c != UserInfo.getUserId() && !PS_Util.isHrUser()) {
            throw new PS_Util.PS_Exception('You can only take quizzes for your own enrollments.');
        }
        return le;
    }

    // ---------------- Recommendations ----------------------------------
    public class Recommendation {
        @AuraEnabled public Id courseId;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public String level;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public Integer score;
        @AuraEnabled public List<String> reasons;
    }

    /**
     * Ranks courses for an employee. Transparent scoring:
     *  +3 per skill the employee's designation requires but the employee lacks (skill gap)
     *  +2 per skill demanded by open requisitions that the employee lacks (market demand)
     *  +1 if the course targets the employee's department
     * Courses whose prerequisite is not completed are excluded.
     */
    public static List<Recommendation> recommend(Id employeeId, Integer max) {
        Employee__c e = [SELECT Id, Skills__c, Department__c, Designation__r.Required_Skills__c,
                         (SELECT Course__c, Status__c FROM Enrollments__r) FROM Employee__c WHERE Id = :employeeId];
        Set<String> have = PS_Util.splitSkills(e.Skills__c);
        Set<String> roleNeeds = PS_Util.splitSkills(e.Designation__r?.Required_Skills__c);
        Set<String> demand = new Set<String>();
        for (Job_Requisition__c r : [SELECT Required_Skills__c FROM Job_Requisition__c WHERE Status__c = 'Open' LIMIT 200]) {
            demand.addAll(PS_Util.splitSkills(r.Required_Skills__c));
        }
        Set<Id> enrolled = new Set<Id>(), completed = new Set<Id>();
        for (Learning_Enrollment__c le : e.Enrollments__r) {
            if (le.Status__c != 'Waived') enrolled.add(le.Course__c);
            if (le.Status__c == 'Completed') completed.add(le.Course__c);
        }
        List<Recommendation> out = new List<Recommendation>();
        for (Learning_Course__c c : [
            SELECT Id, Name, Category__c, Level__c, Duration_Hours__c, Skills_Covered__c, Target_Department__c, Prerequisite_Course__c
            FROM Learning_Course__c WHERE Active__c = true AND Id NOT IN :enrolled LIMIT 500
        ]) {
            if (c.Prerequisite_Course__c != null && !completed.contains(c.Prerequisite_Course__c)) continue;
            Recommendation r = new Recommendation();
            r.courseId = c.Id; r.name = c.Name; r.category = c.Category__c; r.level = c.Level__c; r.hours = c.Duration_Hours__c;
            r.score = 0;
            r.reasons = new List<String>();
            for (String s : PS_Util.splitSkills(c.Skills_Covered__c)) {
                if (have.contains(s)) continue;
                if (roleNeeds.contains(s)) { r.score += 3; r.reasons.add('Closes a skill gap for your role: ' + s); }
                else if (demand.contains(s)) { r.score += 2; r.reasons.add('In demand on open positions: ' + s); }
            }
            if (c.Target_Department__c != null && c.Target_Department__c == e.Department__c) { r.score += 1; r.reasons.add('Recommended for your department'); }
            if (r.score > 0) out.add(r);
        }
        // simple selection sort by score (lists are small)
        for (Integer i = 0; i < out.size(); i++) {
            for (Integer j = i + 1; j < out.size(); j++) {
                if (out[j].score > out[i].score) { Recommendation t = out[i]; out[i] = out[j]; out[j] = t; }
            }
        }
        while (out.size() > max) out.remove(out.size() - 1);
        return out;
    }

    public static Integer markOverdue() {
        List<Learning_Enrollment__c> rows = [
            SELECT Id FROM Learning_Enrollment__c WHERE Status__c IN ('Assigned', 'In Progress') AND Due_Date__c < TODAY LIMIT 5000];
        for (Learning_Enrollment__c le : rows) le.Status__c = 'Overdue';
        if (!rows.isEmpty()) update rows;
        return rows.size();
    }
}
