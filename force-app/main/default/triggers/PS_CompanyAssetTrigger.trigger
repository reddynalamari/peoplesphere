trigger PS_CompanyAssetTrigger on Company_Asset__c (before insert, before update, after update) {
    if (PS_Util.bypassTriggers) return;
    if (Trigger.isBefore) PS_OffboardingService.beforeAssetSave(Trigger.new, Trigger.oldMap);
    else PS_OffboardingService.afterAssetUpdate(Trigger.new, Trigger.oldMap);
}
