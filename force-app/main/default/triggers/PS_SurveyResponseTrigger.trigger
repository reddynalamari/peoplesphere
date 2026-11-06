trigger PS_SurveyResponseTrigger on Survey_Response__c (before insert) {
    if (PS_Util.bypassTriggers) return;
    PS_TalentService.beforeSurveyResponseInsert(Trigger.new);
}
