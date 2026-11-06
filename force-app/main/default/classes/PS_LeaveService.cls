/**
 * Leave, attendance and expense workflows: working-day calculation, balance
 * validation, overlap detection, approvals and attendance integration.
 */
public without sharing class PS_LeaveService {

    public static final Map<String, String> BALANCE_FIELD = new Map<String, String>{
        'Casual Leave' => 'Casual_Leave_Balance__c',
        'Sick Leave' => 'Sick_Leave_Balance__c',
        'Earned Leave' => 'Earned_Leave_Balance__c'
    };

    // ---------------- Leave --------------------------------------------
    public static void beforeLeaveSave(List<Leave_Request__c> rows, Map<Id, Leave_Request__c> oldMap) {
        Set<Id> empIds = new Set<Id>();
        Date minD = Date.today().addYears(5), maxD = Date.today().addYears(-5);
        for (Leave_Request__c l : rows) {
            empIds.add(l.Employee__c);
            if (l.Start_Date__c != null && l.Start_Date__c < minD) minD = l.Start_Date__c;
            if (l.End_Date__c != null && l.End_Date__c > maxD) maxD = l.End_Date__c;
        }
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, Location__c, Manager__r.User__c, Casual_Leave_Balance__c, Sick_Leave_Balance__c, Earned_Leave_Balance__c,
                   (SELECT Id, Start_Date__c, End_Date__c FROM Leave_Requests__r WHERE Status__c IN ('Submitted', 'Approved'))
            FROM Employee__c WHERE Id IN :empIds]);
        Set<Id> locIds = new Set<Id>();
        for (Employee__c e : emps.values()) locIds.add(e.Location__c);
        Set<Date> hol = PS_Util.holidays(minD, maxD, locIds);

        for (Leave_Request__c l : rows) {
            Leave_Request__c old = oldMap == null ? null : oldMap.get(l.Id);
            Employee__c e = emps.get(l.Employee__c);
            if (l.Start_Date__c == null || l.End_Date__c == null) continue;
            if (l.End_Date__c < l.Start_Date__c) { l.End_Date__c.addError('End date must be on or after the start date.'); continue; }
            if (l.Half_Day__c && l.Start_Date__c != l.End_Date__c) { l.Half_Day__c.addError('Half day leave must start and end on the same day.'); continue; }

            Integer days = PS_Util.workingDates(l.Start_Date__c, l.End_Date__c, hol).size();
            l.Number_of_Days__c = l.Half_Day__c ? (days > 0 ? 0.5 : 0) : days;
            if (l.Number_of_Days__c == 0 && l.Status__c != 'Cancelled') {
                l.addError('The selected dates fall on weekends or holidays only.');
                continue;
            }
            if (l.Approver__c == null) l.Approver__c = e?.Manager__r?.User__c != null ? e.Manager__r.User__c : UserInfo.getUserId();

            Boolean activeNow = l.Status__c == 'Submitted' || l.Status__c == 'Approved';
            Boolean datesChanged = old == null || old.Start_Date__c != l.Start_Date__c || old.End_Date__c != l.End_Date__c || old.Status__c != l.Status__c;
            if (activeNow && datesChanged && e != null) {
                for (Leave_Request__c other : e.Leave_Requests__r) {
                    if (other.Id == l.Id) continue;
                    if (other.Start_Date__c <= l.End_Date__c && other.End_Date__c >= l.Start_Date__c) {
                        l.addError('This request overlaps another pending or approved leave (' + other.Start_Date__c.format() + ' - ' + other.End_Date__c.format() + ').');
                        break;
                    }
                }
            }
            Boolean newlySubmitted = l.Status__c == 'Submitted' && (old == null || old.Status__c != 'Submitted');
            String balField = BALANCE_FIELD.get(l.Leave_Type__c);
            if (newlySubmitted && balField != null && e != null) {
                Decimal bal = (Decimal) e.get(balField);
                if (bal == null || bal < l.Number_of_Days__c) {
                    l.addError('Insufficient ' + l.Leave_Type__c + ' balance. Available: ' + (bal == null ? 0 : bal) + ' day(s), requested: ' + l.Number_of_Days__c + '.');
                }
            }
            if (old != null && old.Status__c != l.Status__c && (l.Status__c == 'Approved' || l.Status__c == 'Rejected')) {
                l.Decision_Date__c = System.now();
            }
        }
    }

    public static void afterLeaveSave(List<Leave_Request__c> rows, Map<Id, Leave_Request__c> oldMap) {
        Map<Id, Decimal> deltaCasual = new Map<Id, Decimal>(), deltaSick = new Map<Id, Decimal>(), deltaEarned = new Map<Id, Decimal>();
        List<Leave_Request__c> approved = new List<Leave_Request__c>();
        Set<Id> empIds = new Set<Id>();
        for (Leave_Request__c l : rows) {
            Leave_Request__c old = oldMap == null ? null : oldMap.get(l.Id);
            String oldStatus = old == null ? null : old.Status__c;
            if (l.Status__c == oldStatus) continue;
            empIds.add(l.Employee__c);
            Decimal delta = 0;
            if (l.Status__c == 'Approved') { delta = -l.Number_of_Days__c; approved.add(l); }
            if (oldStatus == 'Approved' && (l.Status__c == 'Cancelled' || l.Status__c == 'Rejected')) delta = l.Number_of_Days__c;
            String f = BALANCE_FIELD.get(l.Leave_Type__c);
            if (delta != 0 && f != null) {
                Map<Id, Decimal> target = f == 'Casual_Leave_Balance__c' ? deltaCasual : (f == 'Sick_Leave_Balance__c' ? deltaSick : deltaEarned);
                target.put(l.Employee__c, (target.containsKey(l.Employee__c) ? target.get(l.Employee__c) : 0) + delta);
            }
        }
        if (empIds.isEmpty()) return;
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, Name, User__c, Location__c, Work_Mode__c, Casual_Leave_Balance__c, Sick_Leave_Balance__c, Earned_Leave_Balance__c
            FROM Employee__c WHERE Id IN :empIds]);
        List<Employee__c> balUpdates = new List<Employee__c>();
        for (Employee__c e : emps.values()) {
            if (!deltaCasual.containsKey(e.Id) && !deltaSick.containsKey(e.Id) && !deltaEarned.containsKey(e.Id)) continue;
            balUpdates.add(new Employee__c(Id = e.Id,
                Casual_Leave_Balance__c = nz(e.Casual_Leave_Balance__c) + nz(deltaCasual.get(e.Id)),
                Sick_Leave_Balance__c = nz(e.Sick_Leave_Balance__c) + nz(deltaSick.get(e.Id)),
                Earned_Leave_Balance__c = nz(e.Earned_Leave_Balance__c) + nz(deltaEarned.get(e.Id))));
        }
        if (!balUpdates.isEmpty()) update balUpdates;

        // Mark approved days on the attendance register
        List<Attendance__c> att = new List<Attendance__c>();
        for (Leave_Request__c l : approved) {
            Employee__c e = emps.get(l.Employee__c);
            Set<Date> hol = PS_Util.holidays(l.Start_Date__c, l.End_Date__c, new Set<Id>{ e.Location__c });
            for (Date d : PS_Util.workingDates(l.Start_Date__c, l.End_Date__c, hol)) {
                Boolean wfh = l.Leave_Type__c == 'Work From Home';
                att.add(new Attendance__c(Employee__c = e.Id, Attendance_Date__c = d,
                    Status__c = wfh ? 'Work From Home' : (l.Half_Day__c ? 'Half Day' : 'On Leave'),
                    Work_Mode__c = wfh ? 'Remote' : e.Work_Mode__c,
                    Unique_Key__c = e.Id + '-' + PS_Util.dateKey(d), Notes__c = l.Leave_Type__c));
            }
        }
        if (!att.isEmpty()) Database.upsert(att, Attendance__c.Unique_Key__c, false);

        for (Leave_Request__c l : rows) {
            Leave_Request__c old = oldMap == null ? null : oldMap.get(l.Id);
            Employee__c e = emps.get(l.Employee__c);
            if (old == null && l.Status__c == 'Submitted') {
                PS_Util.notify(l.Approver__c, 'Leave approval needed: ' + e.Name,
                    l.Leave_Type__c + ' - ' + l.Number_of_Days__c + ' day(s) from ' + l.Start_Date__c.format(), l.Id);
            } else if (old != null && old.Status__c != l.Status__c && (l.Status__c == 'Approved' || l.Status__c == 'Rejected')) {
                PS_Util.notify(e.User__c, 'Your leave was ' + l.Status__c.toLowerCase(),
                    l.Leave_Type__c + ' from ' + l.Start_Date__c.format() + (String.isBlank(l.Approver_Comments__c) ? '' : ': ' + l.Approver_Comments__c), l.Id);
            }
        }
    }

    /** Approve or reject a leave request. Only the approver or HR can decide. */
    public static void decideLeave(Id leaveId, Boolean approve, String comments) {
        Leave_Request__c l = [SELECT Id, Status__c, Approver__c FROM Leave_Request__c WHERE Id = :leaveId];
        if (l.Approver__c != UserInfo.getUserId() && !PS_Util.isHrUser()) throw new PS_Util.PS_Exception('You are not the approver for this request.');
        if (l.Status__c != 'Submitted') throw new PS_Util.PS_Exception('Only submitted requests can be decided (current status: ' + l.Status__c + ').');
        l.Status__c = approve ? 'Approved' : 'Rejected';
        l.Approver_Comments__c = comments == null ? null : comments.abbreviate(255);
        update l;
    }

    public static void decideExpense(Id claimId, Boolean approve, String comments) {
        Expense_Claim__c c = [SELECT Id, Status__c, Approver__c, Employee__r.User__c, Amount__c FROM Expense_Claim__c WHERE Id = :claimId];
        if (c.Approver__c != UserInfo.getUserId() && !PS_Util.isHrUser()) throw new PS_Util.PS_Exception('You are not the approver for this claim.');
        if (c.Status__c != 'Submitted') throw new PS_Util.PS_Exception('Only submitted claims can be decided.');
        c.Status__c = approve ? 'Approved' : 'Rejected';
        c.Approver_Comments__c = comments == null ? null : comments.abbreviate(255);
        c.Decision_Date__c = System.now();
        update c;
        PS_Util.notify(c.Employee__r.User__c, 'Expense claim ' + c.Status__c.toLowerCase(), 'Amount: ' + c.Amount__c, c.Id);
    }

    public static void beforeExpenseSave(List<Expense_Claim__c> rows) {
        Set<Id> empIds = new Set<Id>();
        for (Expense_Claim__c c : rows) empIds.add(c.Employee__c);
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([SELECT Id, Manager__r.User__c FROM Employee__c WHERE Id IN :empIds]);
        for (Expense_Claim__c c : rows) {
            if (c.Amount__c != null && c.Amount__c <= 0) c.Amount__c.addError('Amount must be greater than zero.');
            if (c.Expense_Date__c != null && c.Expense_Date__c > Date.today()) c.Expense_Date__c.addError('Expense date cannot be in the future.');
            if (c.Approver__c == null) {
                Id mgr = emps.get(c.Employee__c)?.Manager__r?.User__c;
                c.Approver__c = mgr != null ? mgr : UserInfo.getUserId();
            }
        }
    }

    // ---------------- Attendance ---------------------------------------
    public static void beforeAttendanceSave(List<Attendance__c> rows) {
        Set<Id> empIds = new Set<Id>();
        for (Attendance__c a : rows) empIds.add(a.Employee__c);
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([
            SELECT Id, Location__r.Office_Start_Time__c, Location__r.Late_Grace_Minutes__c FROM Employee__c WHERE Id IN :empIds]);
        for (Attendance__c a : rows) {
            if (a.Attendance_Date__c == null) a.Attendance_Date__c = Date.today();
            a.Unique_Key__c = a.Employee__c + '-' + PS_Util.dateKey(a.Attendance_Date__c);
            if (a.Check_Out__c != null && a.Check_In__c != null && a.Check_Out__c < a.Check_In__c) a.Check_Out__c.addError('Check-out cannot be before check-in.');
            Employee__c e = emps.get(a.Employee__c);
            String start = e?.Location__r?.Office_Start_Time__c;
            if (a.Check_In__c != null && String.isNotBlank(start) && start.contains(':')) {
                try {
                    Integer h = Integer.valueOf(start.substringBefore(':'));
                    Integer m = Integer.valueOf(start.substringAfter(':'));
                    Integer grace = e.Location__r.Late_Grace_Minutes__c == null ? 15 : e.Location__r.Late_Grace_Minutes__c.intValue();
                    Integer inMinutes = a.Check_In__c.hour() * 60 + a.Check_In__c.minute();
                    a.Late_Arrival__c = inMinutes > (h * 60 + m + grace);
                } catch (Exception ex) {
                    a.Late_Arrival__c = false;
                }
            }
        }
    }

    public static Attendance__c checkIn(Id employeeId, String workMode) {
        String key = employeeId + '-' + PS_Util.dateKey(Date.today());
        List<Attendance__c> existing = [SELECT Id, Check_In__c, Status__c FROM Attendance__c WHERE Unique_Key__c = :key];
        if (!existing.isEmpty() && existing[0].Check_In__c != null) throw new PS_Util.PS_Exception('You have already checked in today.');
        Attendance__c a = existing.isEmpty() ? new Attendance__c(Employee__c = employeeId, Attendance_Date__c = Date.today()) : existing[0];
        a.Check_In__c = System.now();
        a.Status__c = workMode == 'Remote' ? 'Work From Home' : 'Present';
        a.Work_Mode__c = String.isBlank(workMode) ? 'Office' : workMode;
        upsert a;
        return [SELECT Id, Check_In__c, Check_Out__c, Status__c, Late_Arrival__c, Hours_Worked__c, Work_Mode__c FROM Attendance__c WHERE Id = :a.Id];
    }

    public static Attendance__c checkOut(Id employeeId) {
        String key = employeeId + '-' + PS_Util.dateKey(Date.today());
        List<Attendance__c> existing = [SELECT Id, Check_In__c, Check_Out__c FROM Attendance__c WHERE Unique_Key__c = :key];
        if (existing.isEmpty() || existing[0].Check_In__c == null) throw new PS_Util.PS_Exception('Check in before checking out.');
        existing[0].Check_Out__c = System.now();
        update existing[0];
        return [SELECT Id, Check_In__c, Check_Out__c, Status__c, Late_Arrival__c, Hours_Worked__c, Work_Mode__c FROM Attendance__c WHERE Id = :existing[0].Id];
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }
}
