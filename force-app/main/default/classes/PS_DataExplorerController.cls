/**
 * Read-only explorer over every PeopleSphere object, so HR can browse any
 * module's records from one screen. Columns are derived from the schema:
 * Name, then up to 10 custom fields (lookups are shown by name).
 */
public inherited sharing class PS_DataExplorerController {

    public static final List<String> OBJECTS = new List<String>{
        'Employee__c', 'Organization__c', 'Business_Unit__c', 'Department__c', 'Location__c', 'Designation__c',
        'Employment_History__c', 'Employee_Document__c', 'Checklist_Template__c', 'Onboarding__c', 'Onboarding_Task__c',
        'Exit_Process__c', 'Exit_Task__c', 'Learning_Course__c', 'Learning_Enrollment__c', 'Certification__c',
        'Performance_Review__c', 'Goal__c', 'Compensation_Revision__c', 'Mentorship__c', 'Holiday__c', 'Leave_Request__c',
        'Attendance__c', 'HR_Policy__c', 'Policy_Acknowledgement__c', 'HR_Ticket__c', 'Company_Asset__c', 'Expense_Claim__c',
        'Job_Requisition__c', 'Candidate__c', 'Interview__c', 'Pulse_Survey__c', 'Survey_Response__c', 'Recognition__c', 'Announcement__c'
    };
    private static final Set<String> SKIP_TYPES = new Set<String>{ 'TEXTAREA', 'ENCRYPTEDSTRING', 'BASE64', 'ADDRESS', 'LOCATION' };

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getObjects() {
        try {
            requireHr();
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            List<Map<String, Object>> out = new List<Map<String, Object>>();
            for (String api : OBJECTS) {
                Schema.DescribeSObjectResult d = gd.get(api).getDescribe();
                out.add(new Map<String, Object>{ 'value' => api, 'label' => d.getLabelPlural(),
                    'count' => Database.countQuery('SELECT COUNT() FROM ' + api) });
            }
            return out;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getRecords(String objectApiName, String term) {
        try {
            requireHr();
            if (!OBJECTS.contains(objectApiName)) throw new PS_Util.PS_Exception('Unknown object.');
            Schema.DescribeSObjectResult d = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fields = d.fields.getMap();
            List<String> names = new List<String>(fields.keySet());
            names.sort();
            List<String> selects = new List<String>{ 'Id', 'Name' };
            List<Map<String, Object>> columns = new List<Map<String, Object>>{
                new Map<String, Object>{ 'label' => fields.get('name').getDescribe().getLabel(), 'fieldName' => 'Name' } };
            for (String key : names) {
                if (columns.size() >= 11) break;
                Schema.DescribeFieldResult f = fields.get(key).getDescribe();
                if (!f.isCustom() || SKIP_TYPES.contains(String.valueOf(f.getType()))) continue;
                if (!PS_Util.canSee(f)) continue;
                String apiName = f.getName();
                String ftype = String.valueOf(f.getType());
                if (ftype == 'REFERENCE') {
                    String rel = f.getRelationshipName();
                    selects.add(rel + '.Name');
                    columns.add(new Map<String, Object>{ 'label' => f.getLabel(), 'fieldName' => rel + '_Name' });
                } else {
                    selects.add(apiName);
                    columns.add(new Map<String, Object>{ 'label' => f.getLabel(), 'fieldName' => apiName, 'type' => columnType(ftype) });
                }
            }
            String soql = 'SELECT ' + String.join(selects, ', ') + ' FROM ' + objectApiName;
            if (String.isNotBlank(term)) soql += ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(term.trim()) + '%\'';
            soql += ' ORDER BY LastModifiedDate DESC LIMIT 200';
            List<Map<String, Object>> rows = new List<Map<String, Object>>();
            for (SObject rec : Database.query(soql)) {
                Map<String, Object> row = new Map<String, Object>{ 'Id' => rec.Id, 'Name' => rec.get('Name') };
                for (Integer i = 2; i < selects.size(); i++) {
                    String path = selects[i];
                    if (path.endsWith('.Name')) {
                        SObject parent = rec.getSObject(path.substringBefore('.'));
                        row.put(path.substringBefore('.') + '_Name', parent == null ? null : parent.get('Name'));
                    } else {
                        row.put(path, rec.get(path));
                    }
                }
                rows.add(row);
            }
            return new Map<String, Object>{ 'columns' => columns, 'rows' => rows, 'label' => d.getLabelPlural() };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    private static String columnType(String t) {
        switch on t {
            when 'CURRENCY' { return 'currency'; }
            when 'DOUBLE', 'INTEGER' { return 'number'; }
            when 'PERCENT' { return 'number'; }
            when 'BOOLEAN' { return 'boolean'; }
            when 'DATE' { return 'date-local'; }
            when 'DATETIME' { return 'date'; }
            when 'EMAIL' { return 'email'; }
            when 'URL' { return 'url'; }
            when else { return 'text'; }
        }
    }

    private static void requireHr() {
        if (!PS_Util.isHrUser()) throw new PS_Util.PS_Exception('The data explorer is available to HR users only.');
    }
}
