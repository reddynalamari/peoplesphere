trigger PS_OnboardingTaskTrigger on Onboarding_Task__c (before insert, before update, after insert, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_OnboardingService.beforeTaskSave(Trigger.new, Trigger.oldMap);
    else PS_OnboardingService.afterTaskSave(Trigger.new);
}
