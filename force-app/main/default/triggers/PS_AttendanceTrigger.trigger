trigger PS_AttendanceTrigger on Attendance__c (before insert, before update) {
    if (PS_Util.bypassTriggers) return;
    PS_LeaveService.beforeAttendanceSave(Trigger.new);
}
