/**
 * Talent automation: performance reviews, recruitment (skill match, resume
 * summary, hire-to-onboarding conversion, internal mobility), compensation
 * revisions, recognition, engagement surveys and policy acknowledgements.
 */
public without sharing class PS_TalentService {

    // ---------------- Performance --------------------------------------
    public static void beforeReviewSave(List<Performance_Review__c> rows, Map<Id, Performance_Review__c> oldMap) {
        for (Performance_Review__c r : rows) {
            for (String f : new List<String>{ 'Self_Rating__c', 'Manager_Rating__c', 'Final_Rating__c' }) {
                Decimal v = (Decimal) r.get(f);
                if (v != null && (v < 1 || v > 5)) r.addError('Ratings must be between 1 and 5.');
            }
            if (r.Review_Year__c == null) r.Review_Year__c = String.valueOf(Date.today().year());
            Boolean wasDone = oldMap != null && oldMap.get(r.Id).Status__c == 'Completed';
            if (r.Status__c == 'Completed' && !wasDone) {
                if (r.Final_Rating__c == null) r.Final_Rating__c = r.Manager_Rating__c != null ? r.Manager_Rating__c : r.Self_Rating__c;
                if (r.Final_Rating__c == null) r.addError('Provide a manager or final rating before completing the review.');
                r.Completed_On__c = Date.today();
            }
        }
    }

    public static void afterReviewSave(List<Performance_Review__c> rows, Map<Id, Performance_Review__c> oldMap) {
        List<Employee__c> updates = new List<Employee__c>();
        Set<Id> seen = new Set<Id>();
        for (Performance_Review__c r : rows) {
            Boolean wasDone = oldMap != null && oldMap.get(r.Id).Status__c == 'Completed';
            if (r.Status__c == 'Completed' && !wasDone && r.Final_Rating__c != null && seen.add(r.Employee__c)) {
                updates.add(new Employee__c(Id = r.Employee__c, Performance_Rating__c = r.Final_Rating__c));
            }
        }
        if (!updates.isEmpty()) update updates;
    }

    // ---------------- Recruitment --------------------------------------
    public static void beforeCandidateSave(List<Candidate__c> rows, Map<Id, Candidate__c> oldMap) {
        Set<Id> reqIds = new Set<Id>();
        for (Candidate__c c : rows) reqIds.add(c.Job_Requisition__c);
        Map<Id, Job_Requisition__c> reqs = new Map<Id, Job_Requisition__c>([SELECT Id, Required_Skills__c FROM Job_Requisition__c WHERE Id IN :reqIds]);
        for (Candidate__c c : rows) {
            Job_Requisition__c r = reqs.get(c.Job_Requisition__c);
            c.Match_Score__c = matchScore(c.Skills__c, r?.Required_Skills__c);
            if (String.isBlank(c.Resume_Summary__c) && String.isNotBlank(c.Resume_Text__c)) c.Resume_Summary__c = summarizeResume(c);
            if (c.Stage__c == 'Hired' && c.Offer_Status__c != 'Accepted') c.Offer_Status__c = 'Accepted';
            if (c.Stage__c == 'Offer' && c.Offer_Status__c == 'Not Released') {
                c.Offer_Status__c = 'Released';
                if (c.Offer_Date__c == null) c.Offer_Date__c = Date.today();
            }
            if (c.Source__c == 'Internal' && c.Internal_Employee__c == null && oldMap == null) {
                c.Source__c.addError('Select the internal applicant for internal applications.');
            }
        }
    }

    public static Decimal matchScore(String candidateSkills, String requiredSkills) {
        Set<String> need = PS_Util.splitSkills(requiredSkills);
        if (need.isEmpty()) return null;
        Set<String> have = PS_Util.splitSkills(candidateSkills);
        Integer hit = 0;
        for (String s : need) if (have.contains(s)) hit++;
        return Math.round(hit * 100.0 / need.size());
    }

    /** Extractive resume summary: experience, detected skills and the opening lines. */
    public static String summarizeResume(Candidate__c c) {
        String text = c.Resume_Text__c.normalizeSpace();
        List<String> sentences = text.split('(?<=[.!?])\\s+');
        String opening = '';
        for (Integer i = 0; i < Math.min(2, sentences.size()); i++) opening += sentences[i] + ' ';
        List<String> found = new List<String>();
        String lower = text.toLowerCase();
        for (String s : PS_Util.splitSkills(c.Skills__c)) if (lower.contains(s)) found.add(s);
        return ('Experience: ' + (c.Experience_Years__c == null ? 'n/a' : c.Experience_Years__c + ' yrs') +
                (c.Current_Company__c == null ? '' : ' | Current: ' + c.Current_Company__c) +
                (found.isEmpty() ? '' : ' | Skills evidenced in resume: ' + String.join(found, ', ')) +
                '\n' + opening.trim()).abbreviate(5000);
    }

    public static void afterCandidateSave(List<Candidate__c> rows, Map<Id, Candidate__c> oldMap) {
        List<Candidate__c> hired = new List<Candidate__c>();
        Set<Id> reqIds = new Set<Id>();
        for (Candidate__c c : rows) {
            Boolean wasHired = oldMap != null && oldMap.get(c.Id).Stage__c == 'Hired';
            if (c.Stage__c == 'Hired' && !wasHired && c.Converted_Employee__c == null) {
                hired.add(c);
                reqIds.add(c.Job_Requisition__c);
            }
        }
        if (hired.isEmpty()) return;
        Map<Id, Job_Requisition__c> reqs = new Map<Id, Job_Requisition__c>([
            SELECT Id, Department__c, Location__c, Designation__c, Hiring_Manager__c, Employment_Type__c, Openings__c, Filled__c,
                   Department__r.Organization__c
            FROM Job_Requisition__c WHERE Id IN :reqIds]);

        Map<Id, Employee__c> newEmpByCandidate = new Map<Id, Employee__c>();
        List<Employee__c> internalMoves = new List<Employee__c>();
        Map<Id, Integer> filledInc = new Map<Id, Integer>();
        for (Candidate__c c : hired) {
            Job_Requisition__c r = reqs.get(c.Job_Requisition__c);
            if (r != null) filledInc.put(r.Id, (filledInc.containsKey(r.Id) ? filledInc.get(r.Id) : 0) + 1);
            if (c.Internal_Employee__c != null) {
                Employee__c move = new Employee__c(Id = c.Internal_Employee__c);
                if (r?.Department__c != null) move.Department__c = r.Department__c;
                if (r?.Designation__c != null) move.Designation__c = r.Designation__c;
                if (r?.Location__c != null) move.Location__c = r.Location__c;
                if (r?.Hiring_Manager__c != null && r.Hiring_Manager__c != c.Internal_Employee__c) move.Manager__c = r.Hiring_Manager__c;
                if (c.Offered_CTC__c != null) move.Annual_CTC__c = c.Offered_CTC__c;
                internalMoves.add(move);
                continue;
            }
            String first = c.Name.contains(' ') ? c.Name.substringBefore(' ') : c.Name;
            String last = c.Name.contains(' ') ? c.Name.substringAfter(' ') : null;
            newEmpByCandidate.put(c.Id, new Employee__c(
                Name = c.Name, First_Name__c = first, Last_Name__c = last, Personal_Email__c = c.Email__c, Phone__c = c.Phone__c,
                Organization__c = r?.Department__r?.Organization__c, Department__c = r?.Department__c, Designation__c = r?.Designation__c,
                Location__c = r?.Location__c, Manager__c = r?.Hiring_Manager__c,
                Employment_Type__c = r?.Employment_Type__c == null ? 'Full-time' : r.Employment_Type__c,
                Date_of_Joining__c = c.Expected_Joining_Date__c != null ? c.Expected_Joining_Date__c : Date.today().addDays(14),
                Annual_CTC__c = c.Offered_CTC__c, Skills__c = c.Skills__c, Status__c = 'Pre-boarding'));
        }
        if (!newEmpByCandidate.isEmpty()) insert newEmpByCandidate.values();
        if (!internalMoves.isEmpty()) update internalMoves;

        List<Candidate__c> links = new List<Candidate__c>();
        for (Candidate__c c : hired) {
            Id empId = newEmpByCandidate.containsKey(c.Id) ? newEmpByCandidate.get(c.Id).Id : c.Internal_Employee__c;
            links.add(new Candidate__c(Id = c.Id, Converted_Employee__c = empId));
        }
        update links;

        List<Job_Requisition__c> reqUpdates = new List<Job_Requisition__c>();
        for (Id rid : filledInc.keySet()) {
            Job_Requisition__c r = reqs.get(rid);
            Decimal filled = (r.Filled__c == null ? 0 : r.Filled__c) + filledInc.get(rid);
            Job_Requisition__c u = new Job_Requisition__c(Id = rid, Filled__c = filled);
            if (r.Openings__c != null && filled >= r.Openings__c) u.Status__c = 'Filled';
            reqUpdates.add(u);
        }
        if (!reqUpdates.isEmpty()) update reqUpdates;
    }

    public static void beforeRequisitionSave(List<Job_Requisition__c> rows, Map<Id, Job_Requisition__c> oldMap) {
        for (Job_Requisition__c r : rows) {
            String old = oldMap == null ? null : oldMap.get(r.Id).Status__c;
            if (r.Status__c == 'Open' && old != 'Open') {
                if (r.Posted_On__c == null) r.Posted_On__c = Date.today();
                if (r.Approved_By__c == null) r.Approved_By__c = UserInfo.getUserId();
            }
        }
    }

    public static void afterInterviewSave(List<Interview__c> rows) {
        Set<Id> candIds = new Set<Id>();
        for (Interview__c i : rows) if (i.Status__c == 'Completed') candIds.add(i.Candidate__c);
        if (candIds.isEmpty()) return;
        List<Candidate__c> updates = new List<Candidate__c>();
        for (AggregateResult ar : [
            SELECT Candidate__c c, AVG(Rating__c) r FROM Interview__c
            WHERE Candidate__c IN :candIds AND Status__c = 'Completed' AND Rating__c != null GROUP BY Candidate__c
        ]) {
            updates.add(new Candidate__c(Id = (Id) ar.get('c'), Overall_Rating__c = ((Decimal) ar.get('r')).setScale(1)));
        }
        if (!updates.isEmpty()) update updates;
    }

    // ---------------- Compensation -------------------------------------
    public static void beforeCompensationSave(List<Compensation_Revision__c> rows, Map<Id, Compensation_Revision__c> oldMap) {
        Set<Id> empIds = new Set<Id>();
        for (Compensation_Revision__c c : rows) empIds.add(c.Employee__c);
        Map<Id, Employee__c> emps = new Map<Id, Employee__c>([SELECT Id, Annual_CTC__c FROM Employee__c WHERE Id IN :empIds]);
        for (Compensation_Revision__c c : rows) {
            if (c.Previous_CTC__c == null) c.Previous_CTC__c = emps.get(c.Employee__c)?.Annual_CTC__c;
            if (c.Effective_Date__c == null) c.Effective_Date__c = Date.today();
            String old = oldMap == null ? null : oldMap.get(c.Id).Status__c;
            if (c.Status__c == 'Approved' && old != 'Approved' && c.Approved_By__c == null) c.Approved_By__c = UserInfo.getUserId();
            if (c.Status__c == 'Applied' && old != 'Applied' && old != 'Approved' && oldMap != null) {
                c.addError('A revision must be approved before it is applied.');
            }
        }
    }

    public static void afterCompensationSave(List<Compensation_Revision__c> rows, Map<Id, Compensation_Revision__c> oldMap) {
        List<Employee__c> updates = new List<Employee__c>();
        for (Compensation_Revision__c c : rows) {
            String old = oldMap == null ? null : oldMap.get(c.Id).Status__c;
            if (c.Status__c == 'Applied' && old != 'Applied' && c.New_CTC__c != null) {
                updates.add(new Employee__c(Id = c.Employee__c, Annual_CTC__c = c.New_CTC__c));
            }
        }
        if (!updates.isEmpty()) update updates;
    }

    // ---------------- Recognition --------------------------------------
    public static void beforeRecognitionInsert(List<Recognition__c> rows) {
        Employee__c me = PS_Util.currentEmployee();
        for (Recognition__c r : rows) {
            if (r.Giver__c == null && me != null) r.Giver__c = me.Id;
            if (r.Giver__c != null && r.Giver__c == r.Recipient__c) r.addError('You cannot recognize yourself.');
            if (r.Points__c == null) r.Points__c = 10;
            if (r.Points__c > 100) r.Points__c.addError('A single recognition can award at most 100 points.');
        }
    }

    public static void afterRecognitionInsert(List<Recognition__c> rows) {
        Map<Id, Decimal> add = new Map<Id, Decimal>();
        for (Recognition__c r : rows) {
            if (r.Recipient__c == null) continue;
            add.put(r.Recipient__c, (add.containsKey(r.Recipient__c) ? add.get(r.Recipient__c) : 0) + r.Points__c);
        }
        if (add.isEmpty()) return;
        List<Employee__c> updates = new List<Employee__c>();
        for (Employee__c e : [SELECT Id, User__c, Recognition_Points__c FROM Employee__c WHERE Id IN :add.keySet()]) {
            updates.add(new Employee__c(Id = e.Id, Recognition_Points__c = (e.Recognition_Points__c == null ? 0 : e.Recognition_Points__c) + add.get(e.Id)));
            PS_Util.notify(e.User__c, 'You received a recognition!', '+' + add.get(e.Id) + ' points', e.Id);
        }
        update updates;
    }

    // ---------------- Surveys ------------------------------------------
    public static void beforeSurveyResponseInsert(List<Survey_Response__c> rows) {
        Set<Id> surveyIds = new Set<Id>();
        for (Survey_Response__c r : rows) surveyIds.add(r.Pulse_Survey__c);
        Map<Id, Pulse_Survey__c> surveys = new Map<Id, Pulse_Survey__c>([SELECT Id, Anonymous__c, Active__c FROM Pulse_Survey__c WHERE Id IN :surveyIds]);
        Employee__c me = PS_Util.currentEmployee();
        for (Survey_Response__c r : rows) {
            Pulse_Survey__c s = surveys.get(r.Pulse_Survey__c);
            if (r.Score__c == null || r.Score__c < 0 || r.Score__c > 10) { r.Score__c.addError('Score must be between 0 and 10.'); continue; }
            if (s != null && !s.Active__c) { r.addError('This survey is closed.'); continue; }
            r.Sentiment__c = r.Score__c >= 9 ? 'Positive' : (r.Score__c >= 7 ? 'Neutral' : 'Negative');
            if (r.Department__c == null && me != null) r.Department__c = me.Department__c;
            if (String.isBlank(r.Respondent_Key__c)) r.Respondent_Key__c = respondentKey(r.Pulse_Survey__c, UserInfo.getUserId());
            if (s != null && s.Anonymous__c) r.Employee__c = null;
            else if (r.Employee__c == null && me != null) r.Employee__c = me.Id;
        }
    }

    /** One-way hash so a person can answer only once while staying anonymous. */
    public static String respondentKey(Id surveyId, Id userId) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(surveyId + ':' + userId))).left(64);
    }

    // ---------------- Policy acknowledgements --------------------------
    public static void beforeAcknowledgementInsert(List<Policy_Acknowledgement__c> rows) {
        Set<Id> policyIds = new Set<Id>();
        for (Policy_Acknowledgement__c a : rows) policyIds.add(a.HR_Policy__c);
        Map<Id, HR_Policy__c> pols = new Map<Id, HR_Policy__c>([SELECT Id, Version__c FROM HR_Policy__c WHERE Id IN :policyIds]);
        for (Policy_Acknowledgement__c a : rows) {
            if (a.Acknowledged_On__c == null) a.Acknowledged_On__c = System.now();
            if (a.Version__c == null) a.Version__c = pols.get(a.HR_Policy__c)?.Version__c;
            a.Unique_Key__c = a.HR_Policy__c + '-' + a.Employee__c + '-' + (a.Version__c == null ? '1' : a.Version__c);
        }
    }

    public static void afterAcknowledgementInsert(List<Policy_Acknowledgement__c> rows) {
        Set<Id> policyIds = new Set<Id>();
        for (Policy_Acknowledgement__c a : rows) policyIds.add(a.HR_Policy__c);
        Set<Id> handbook = new Map<Id, HR_Policy__c>([
            SELECT Id FROM HR_Policy__c WHERE Id IN :policyIds AND (Name LIKE '%Handbook%' OR Category__c = 'Code of Conduct')]).keySet();
        List<Employee__c> updates = new List<Employee__c>();
        Set<Id> seen = new Set<Id>();
        for (Policy_Acknowledgement__c a : rows) {
            if (handbook.contains(a.HR_Policy__c) && seen.add(a.Employee__c)) updates.add(new Employee__c(Id = a.Employee__c, Handbook_Acknowledged__c = true));
        }
        if (!updates.isEmpty()) update updates;
    }
}
