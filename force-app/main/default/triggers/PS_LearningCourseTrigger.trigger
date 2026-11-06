trigger PS_LearningCourseTrigger on Learning_Course__c (after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    PS_LearningService.afterCourseSave(Trigger.new, Trigger.oldMap);
}
