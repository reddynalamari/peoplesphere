trigger PS_LearningEnrollmentTrigger on Learning_Enrollment__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_LearningService.beforeEnrollmentSave(Trigger.new, Trigger.oldMap);
    else PS_LearningService.afterEnrollmentSave(Trigger.new, Trigger.oldMap);
}
