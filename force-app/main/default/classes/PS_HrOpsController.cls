/**
 * HR operations console: service-desk queue management, the open onboarding
 * pipeline and the recruitment pipeline. HR users only.
 */
public inherited sharing class PS_HrOpsController {

    private static void requireHr() {
        if (!PS_Util.isHrUser()) throw new PS_Util.PS_Exception('This console is available to HR users only.');
    }

    // ---------------- Service desk ------------------------------------------
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getTickets(String view) {
        try {
            requireHr();
            Datetime nowTs = System.now();
            Id me = UserInfo.getUserId();
            String base = 'SELECT Id, Name, Subject__c, Description__c, Category__c, Priority__c, Status__c, Channel__c, SLA_Due__c, SLA_Breached__c, ' +
                          'Escalated__c, Confidential__c, Resolution__c, AI_Suggested_Category__c, AI_Confidence__c, Satisfaction_Rating__c, CreatedDate, ' +
                          'Employee__r.Name, Assigned_To__r.Name, Related_Policy__r.Name FROM HR_Ticket__c ';
            String filter = view == 'breached' ? 'WHERE Status__c NOT IN (\'Resolved\', \'Closed\') AND SLA_Due__c < :nowTs '
                         : view == 'mine' ? 'WHERE Status__c NOT IN (\'Resolved\', \'Closed\') AND Assigned_To__c = :me '
                         : view == 'closed' ? 'WHERE Status__c IN (\'Resolved\', \'Closed\') '
                         : view == 'all' ? ''
                         : 'WHERE Status__c NOT IN (\'Resolved\', \'Closed\') ';
            List<HR_Ticket__c> rows = Database.query(base + filter + 'ORDER BY SLA_Due__c NULLS LAST LIMIT 200');
            Map<String, Object> counts = new Map<String, Object>{
                'open' => [SELECT COUNT() FROM HR_Ticket__c WHERE Status__c NOT IN ('Resolved', 'Closed')],
                'breached' => [SELECT COUNT() FROM HR_Ticket__c WHERE Status__c NOT IN ('Resolved', 'Closed') AND SLA_Due__c < :nowTs],
                'escalated' => [SELECT COUNT() FROM HR_Ticket__c WHERE Status__c = 'Escalated'],
                'resolved30' => [SELECT COUNT() FROM HR_Ticket__c WHERE Resolved_On__c = LAST_N_DAYS:30]
            };
            return new Map<String, Object>{ 'tickets' => rows, 'counts' => counts };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @AuraEnabled
    public static void updateTicket(Id ticketId, String status, String priority, String resolution) {
        try {
            requireHr();
            HR_Ticket__c t = new HR_Ticket__c(Id = ticketId);
            if (String.isNotBlank(status)) t.Status__c = status;
            if (String.isNotBlank(priority)) t.Priority__c = priority;
            if (resolution != null) t.Resolution__c = resolution;
            update t;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @AuraEnabled
    public static Integer runEscalation() {
        try {
            requireHr();
            return PS_TicketService.escalateBreached();
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    // ---------------- Onboarding pipeline -----------------------------------
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getOpenOnboardings() {
        try {
            requireHr();
            List<Map<String, Object>> out = new List<Map<String, Object>>();
            for (Onboarding__c o : [SELECT Id, Name, Status__c, Completion_Percent__c, Start_Date__c, Target_Completion_Date__c, Days_Elapsed__c,
                                           Employee__r.Name, Employee__r.Department__r.Name, Employee__r.Designation__r.Name
                                    FROM Onboarding__c ORDER BY Status__c DESC, Start_Date__c DESC LIMIT 50]) {
                out.add(new Map<String, Object>{ 'id' => o.Id, 'name' => o.Name, 'employee' => o.Employee__r.Name,
                    'department' => o.Employee__r.Department__r?.Name, 'designation' => o.Employee__r.Designation__r?.Name,
                    'status' => o.Status__c, 'percent' => o.Completion_Percent__c == null ? 0 : o.Completion_Percent__c.setScale(0),
                    'start' => o.Start_Date__c, 'late' => o.Status__c != 'Completed' && o.Target_Completion_Date__c != null && o.Target_Completion_Date__c < Date.today() });
            }
            return out;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    // ---------------- Recruitment pipeline ----------------------------------
    public static final List<String> STAGES = new List<String>{ 'Applied', 'Screening', 'Interview', 'Offer', 'Offer Accepted', 'Hired' };

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getPipeline() {
        try {
            requireHr();
            List<Map<String, Object>> reqs = new List<Map<String, Object>>();
            for (Job_Requisition__c r : [
                SELECT Id, Name, Status__c, Priority__c, Openings__c, Filled__c, Days_Open__c, Internal_Posting__c, Required_Skills__c,
                       Department__r.Name, Location__r.Name, Hiring_Manager__r.Name,
                       (SELECT Id, Name, Stage__c, Source__c, Match_Score__c, Overall_Rating__c, Experience_Years__c, Current_Company__c,
                               Resume_Summary__c, Converted_Employee__c, Converted_Employee__r.Name, Internal_Employee__c
                        FROM Candidates__r ORDER BY Match_Score__c DESC NULLS LAST)
                FROM Job_Requisition__c WHERE Status__c IN ('Open', 'Pending Approval', 'On Hold', 'Filled', 'Draft')
                ORDER BY Status__c DESC, Priority__c LIMIT 30
            ]) {
                List<Map<String, Object>> columns = new List<Map<String, Object>>();
                Map<String, List<Candidate__c>> byStage = new Map<String, List<Candidate__c>>();
                for (String s : STAGES) byStage.put(s, new List<Candidate__c>());
                Integer rejected = 0;
                for (Candidate__c c : r.Candidates__r) {
                    if (byStage.containsKey(c.Stage__c)) byStage.get(c.Stage__c).add(c); else rejected++;
                }
                for (String s : STAGES) columns.add(new Map<String, Object>{ 'stage' => s, 'candidates' => byStage.get(s), 'count' => byStage.get(s).size() });
                reqs.add(new Map<String, Object>{ 'id' => r.Id, 'name' => r.Name, 'status' => r.Status__c, 'priority' => r.Priority__c,
                    'openings' => r.Openings__c, 'filled' => r.Filled__c, 'daysOpen' => r.Days_Open__c, 'internal' => r.Internal_Posting__c,
                    'skills' => r.Required_Skills__c, 'department' => r.Department__r?.Name, 'location' => r.Location__r?.Name,
                    'manager' => r.Hiring_Manager__r?.Name, 'columns' => columns, 'rejected' => rejected,
                    'total' => r.Candidates__r.size() });
            }
            return new Map<String, Object>{ 'requisitions' => reqs, 'stages' => STAGES };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    /** Moves a candidate. "Hired" creates the employee and starts onboarding automatically. */
    @AuraEnabled
    public static Map<String, Object> moveCandidate(Id candidateId, String stage) {
        try {
            requireHr();
            Candidate__c c = new Candidate__c(Id = candidateId, Stage__c = stage);
            if (stage == 'Rejected') c.Rejection_Reason__c = 'Not progressed by hiring team';
            update c;
            Candidate__c after = [SELECT Converted_Employee__c, Converted_Employee__r.Name, Converted_Employee__r.Employee_ID__c FROM Candidate__c WHERE Id = :candidateId];
            return new Map<String, Object>{ 'employeeId' => after.Converted_Employee__c, 'employeeName' => after.Converted_Employee__r?.Name,
                'employeeNumber' => after.Converted_Employee__r?.Employee_ID__c };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @AuraEnabled
    public static void setRequisitionStatus(Id requisitionId, String status) {
        try {
            requireHr();
            update new Job_Requisition__c(Id = requisitionId, Status__c = status);
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }
}
