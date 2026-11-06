/**
 * Learning endpoints for the portal: catalogue, self-enrolment, quizzes and
 * recommendations.
 */
public inherited sharing class PS_LearningController {

    @AuraEnabled(cacheable=false)
    public static List<Learning_Course__c> getCatalog(String category) {
        try {
            if (String.isBlank(category)) {
                return [SELECT Id, Name, Course_Code__c, Category__c, Delivery_Mode__c, Level__c, Duration_Hours__c, Description__c,
                               Mandatory__c, Prerequisite_Course__r.Name, Total_Questions__c, Skills_Covered__c
                        FROM Learning_Course__c WHERE Active__c = true ORDER BY Category__c, Name LIMIT 200];
            }
            return [SELECT Id, Name, Course_Code__c, Category__c, Delivery_Mode__c, Level__c, Duration_Hours__c, Description__c,
                           Mandatory__c, Prerequisite_Course__r.Name, Total_Questions__c, Skills_Covered__c
                    FROM Learning_Course__c WHERE Active__c = true AND Category__c = :category ORDER BY Name LIMIT 200];
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static Id selfEnroll(Id courseId) {
        try {
            return PS_LearningService.enroll(PS_Util.requireCurrentEmployee().Id, courseId, 'Self Enrolled').Id;
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static PS_LearningService.Quiz getQuiz(Id enrollmentId) {
        try { return PS_LearningService.getQuiz(enrollmentId); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static PS_LearningService.QuizResult submitQuiz(Id enrollmentId, Map<String, String> answers) {
        try { return PS_LearningService.submitQuiz(enrollmentId, answers); }
        catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled
    public static void markContentComplete(Id enrollmentId) {
        try {
            Learning_Enrollment__c le = [SELECT Id, Employee__r.User__c, Course__r.Total_Questions__c, Status__c FROM Learning_Enrollment__c WHERE Id = :enrollmentId];
            if (le.Employee__r.User__c != UserInfo.getUserId() && !PS_Util.isHrUser()) throw new PS_Util.PS_Exception('Not your enrollment.');
            if (le.Course__r.Total_Questions__c != null && le.Course__r.Total_Questions__c > 0) {
                throw new PS_Util.PS_Exception('This course ends with an assessment - pass the quiz to complete it.');
            }
            update new Learning_Enrollment__c(Id = le.Id, Status__c = 'Completed');
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }

    @AuraEnabled(cacheable=false)
    public static List<PS_LearningService.Recommendation> getRecommendations() {
        try {
            Employee__c me = PS_Util.currentEmployee();
            return me == null ? new List<PS_LearningService.Recommendation>() : PS_LearningService.recommend(me.Id, 6);
        } catch (Exception e) { throw PS_Util.auraError(e); }
    }
}
