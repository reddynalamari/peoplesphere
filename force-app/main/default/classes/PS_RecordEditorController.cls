/**
 * Generic record editor for every PeopleSphere object: schema-driven forms,
 * record detail with related lists, create / update / delete and lookup search.
 * HR users only (inside Salesforce, or the password-protected public HR demo).
 * All DML goes through the normal triggers, so automation runs as usual.
 */
public inherited sharing class PS_RecordEditorController {

    private static final Set<String> SYSTEM_FIELDS = new Set<String>{
        'id', 'isdeleted', 'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid', 'systemmodstamp',
        'lastactivitydate', 'lastvieweddate', 'lastreferenceddate', 'ownerid'
    };

    private static void requireHr() {
        if (!PS_Util.isHrUser()) throw new PS_Util.PS_Exception('Editing is available to HR users only.');
    }

    private static Schema.DescribeSObjectResult describe(String objectApiName) {
        if (!PS_DataExplorerController.OBJECTS.contains(objectApiName)) throw new PS_Util.PS_Exception('Unknown object: ' + objectApiName);
        return Schema.getGlobalDescribe().get(objectApiName).getDescribe();
    }

    // ---------------- form schema ------------------------------------------
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> describeObject(String objectApiName) {
        try {
            requireHr();
            Schema.DescribeSObjectResult d = describe(objectApiName);
            List<Map<String, Object>> required = new List<Map<String, Object>>();
            List<Map<String, Object>> optional = new List<Map<String, Object>>();
            for (Schema.SObjectField sf : d.fields.getMap().values()) {
                Schema.DescribeFieldResult f = sf.getDescribe();
                String name = f.getName();
                if (SYSTEM_FIELDS.contains(name.toLowerCase()) || f.isCalculated() || f.isAutoNumber()) continue;
                if (!f.isCreateable() && !f.isUpdateable()) continue;
                if (!PS_Util.canSee(f)) continue;
                Map<String, Object> m = new Map<String, Object>{
                    'name' => name, 'label' => f.getLabel(), 'type' => String.valueOf(f.getType()).toLowerCase(),
                    'required' => !f.isNillable() && f.getType() != Schema.DisplayType.BOOLEAN,
                    'createable' => f.isCreateable(), 'updateable' => f.isUpdateable(),
                    'help' => f.getInlineHelpText(), 'length' => f.getLength()
                };
                if (f.getType() == Schema.DisplayType.PICKLIST || f.getType() == Schema.DisplayType.MULTIPICKLIST) {
                    List<Map<String, String>> opts = new List<Map<String, String>>();
                    for (Schema.PicklistEntry pe : f.getPicklistValues()) if (pe.isActive()) opts.add(new Map<String, String>{ 'label' => pe.getLabel(), 'value' => pe.getValue() });
                    m.put('options', opts);
                    for (Schema.PicklistEntry pe : f.getPicklistValues()) if (pe.isDefaultValue()) m.put('defaultValue', pe.getValue());
                }
                if (f.getType() == Schema.DisplayType.BOOLEAN) m.put('defaultValue', f.getDefaultValue());
                if (f.getType() == Schema.DisplayType.REFERENCE) m.put('referenceTo', String.valueOf(f.getReferenceTo()[0]));
                if (name == 'Name') { if (required.isEmpty()) required.add(m); else required.add(0, m); }
                else if ((Boolean) m.get('required')) required.add(m);
                else optional.add(m);
            }
            sortByLabel(optional);
            List<Map<String, Object>> fields = new List<Map<String, Object>>(required);
            fields.addAll(optional);
            return new Map<String, Object>{ 'objectApiName' => objectApiName, 'label' => d.getLabel(), 'fields' => fields };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    private static void sortByLabel(List<Map<String, Object>> items) {
        for (Integer i = 0; i < items.size(); i++) {
            for (Integer j = i + 1; j < items.size(); j++) {
                if (((String) items[j].get('label')).compareTo((String) items[i].get('label')) < 0) {
                    Map<String, Object> t = items[i]; items[i] = items[j]; items[j] = t;
                }
            }
        }
    }

    // ---------------- record detail ----------------------------------------
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getRecord(String objectApiName, Id recordId) {
        try {
            requireHr();
            Schema.DescribeSObjectResult d = describe(objectApiName);
            Map<String, Schema.SObjectField> fmap = d.fields.getMap();
            List<String> selects = new List<String>{ 'Id', 'CreatedDate', 'LastModifiedDate', 'CreatedBy.Name', 'LastModifiedBy.Name' };
            List<Schema.DescribeFieldResult> shown = new List<Schema.DescribeFieldResult>();
            for (Schema.SObjectField sf : fmap.values()) {
                Schema.DescribeFieldResult f = sf.getDescribe();
                String name = f.getName();
                if (SYSTEM_FIELDS.contains(name.toLowerCase()) || !PS_Util.canSee(f)) continue;
                if (!selects.contains(name)) selects.add(name);
                if (f.getType() == Schema.DisplayType.REFERENCE && f.getRelationshipName() != null) selects.add(f.getRelationshipName() + '.Name');
                shown.add(f);
            }
            SObject rec = Database.query('SELECT ' + String.join(selects, ', ') + ' FROM ' + objectApiName + ' WHERE Id = :recordId');

            Map<String, Object> values = new Map<String, Object>();
            List<Map<String, Object>> display = new List<Map<String, Object>>();
            Map<String, String> lookupLabels = new Map<String, String>();
            for (Schema.DescribeFieldResult f : shown) {
                String name = f.getName();
                Object v = rec.get(name);
                values.put(name, v);
                String text = v == null ? '' : String.valueOf(v);
                Id linkId = null;
                String linkObject = null;
                if (f.getType() == Schema.DisplayType.REFERENCE && v != null) {
                    SObject parent = rec.getSObject(f.getRelationshipName());
                    text = parent == null ? String.valueOf(v) : String.valueOf(parent.get('Name'));
                    lookupLabels.put(name, text);
                    String ref = String.valueOf(f.getReferenceTo()[0]);
                    if (PS_DataExplorerController.OBJECTS.contains(ref)) { linkId = (Id) v; linkObject = ref; }
                } else if (v instanceof Date) {
                    text = ((Date) v).format();
                } else if (v instanceof Datetime) {
                    text = ((Datetime) v).format();
                } else if (v instanceof Boolean) {
                    text = ((Boolean) v) ? 'Yes' : 'No';
                }
                display.add(new Map<String, Object>{ 'name' => name, 'label' => f.getLabel(), 'value' => text, 'linkId' => linkId, 'linkObject' => linkObject,
                    'long' => f.getType() == Schema.DisplayType.TEXTAREA, 'calculated' => f.isCalculated() || f.isAutoNumber() });
            }
            sortDisplay(display);

            List<Map<String, Object>> related = new List<Map<String, Object>>();
            for (Schema.ChildRelationship cr : d.getChildRelationships()) {
                String child = String.valueOf(cr.getChildSObject());
                if (!PS_DataExplorerController.OBJECTS.contains(child) || cr.getRelationshipName() == null) continue;
                String fk = String.valueOf(cr.getField());
                List<Map<String, Object>> rows = new List<Map<String, Object>>();
                for (SObject c : Database.query('SELECT Id, Name FROM ' + child + ' WHERE ' + fk + ' = :recordId ORDER BY CreatedDate DESC LIMIT 25')) {
                    rows.add(new Map<String, Object>{ 'id' => c.Id, 'name' => c.get('Name') });
                }
                related.add(new Map<String, Object>{ 'objectApiName' => child, 'field' => fk,
                    'label' => Schema.getGlobalDescribe().get(child).getDescribe().getLabelPlural() + ' (' + cr.getField().getDescribe().getLabel() + ')',
                    'records' => rows, 'count' => rows.size() });
                if (related.size() >= 40) break;
            }
            return new Map<String, Object>{
                'objectApiName' => objectApiName, 'objectLabel' => d.getLabel(), 'id' => rec.Id, 'name' => rec.get('Name'),
                'values' => values, 'lookupLabels' => lookupLabels, 'fields' => display, 'related' => related,
                'createdBy' => rec.getSObject('CreatedBy')?.get('Name'), 'createdDate' => rec.get('CreatedDate'),
                'modifiedBy' => rec.getSObject('LastModifiedBy')?.get('Name'), 'modifiedDate' => rec.get('LastModifiedDate')
            };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    private static void sortDisplay(List<Map<String, Object>> items) {
        // Name first, editable fields alphabetically, calculated fields last
        for (Integer i = 0; i < items.size(); i++) {
            for (Integer j = i + 1; j < items.size(); j++) {
                if (rank(items[j]).compareTo(rank(items[i])) < 0) { Map<String, Object> t = items[i]; items[i] = items[j]; items[j] = t; }
            }
        }
    }
    private static String rank(Map<String, Object> m) {
        String prefix = m.get('name') == 'Name' ? '0' : ((Boolean) m.get('calculated') ? '2' : '1');
        return prefix + (String) m.get('label');
    }

    // ---------------- save / delete -----------------------------------------
    /** Creates (recordId null) or updates a record. valuesJson: {"Field__c": value, ...}. Returns the record Id. */
    @AuraEnabled
    public static Id saveRecord(String objectApiName, Id recordId, String valuesJson) {
        try {
            requireHr();
            Schema.DescribeSObjectResult d = describe(objectApiName);
            Map<String, Schema.SObjectField> fmap = d.fields.getMap();
            Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(String.isBlank(valuesJson) ? '{}' : valuesJson);
            SObject rec = Schema.getGlobalDescribe().get(objectApiName).newSObject(recordId);
            for (String key : input.keySet()) {
                Schema.SObjectField sf = fmap.get(key.toLowerCase());
                if (sf == null) throw new PS_Util.PS_Exception('Unknown field ' + key);
                Schema.DescribeFieldResult f = sf.getDescribe();
                if (SYSTEM_FIELDS.contains(f.getName().toLowerCase()) || f.isCalculated() || f.isAutoNumber()) continue;
                if (recordId == null ? !f.isCreateable() : !f.isUpdateable()) continue;
                if (!PS_Util.canSee(f)) continue;
                rec.put(f.getName(), convert(f, input.get(key)));
            }
            if (recordId == null) insert rec; else update rec;
            return rec.Id;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    @TestVisible
    private static Object convert(Schema.DescribeFieldResult f, Object v) {
        if (v == null || (v instanceof String && String.isBlank((String) v))) {
            return f.getType() == Schema.DisplayType.BOOLEAN ? (Object) false : null;
        }
        String s = String.valueOf(v);
        switch on f.getType() {
            when BOOLEAN { return v instanceof Boolean ? v : Boolean.valueOf(s); }
            when DATE { return Date.valueOf(s.left(10)); }
            when DATETIME { return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class); }
            when CURRENCY, DOUBLE, PERCENT { return Decimal.valueOf(s); }
            when INTEGER { return Decimal.valueOf(s).intValue(); }
            when REFERENCE, ID { return Id.valueOf(s); }
            when else { return s; }
        }
    }

    @AuraEnabled
    public static void deleteRecord(String objectApiName, Id recordId) {
        try {
            requireHr();
            describe(objectApiName);
            if (String.valueOf(recordId.getSObjectType()) != objectApiName) throw new PS_Util.PS_Exception('Record does not belong to ' + objectApiName);
            Database.delete(recordId);
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    // ---------------- lookups ------------------------------------------------
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> searchLookup(String objectApiName, String term) {
        try {
            requireHr();
            List<Map<String, String>> out = new List<Map<String, String>>();
            String pattern = '%' + (term == null ? '' : String.escapeSingleQuotes(term.trim())) + '%';
            if (objectApiName == 'User') {
                for (User u : [SELECT Id, Name FROM User WHERE IsActive = true AND UserType = 'Standard' AND Name LIKE :pattern ORDER BY Name LIMIT 20]) {
                    out.add(new Map<String, String>{ 'value' => u.Id, 'label' => u.Name });
                }
                return out;
            }
            describe(objectApiName);
            for (SObject r : Database.query('SELECT Id, Name FROM ' + objectApiName + ' WHERE Name LIKE :pattern ORDER BY Name LIMIT 20')) {
                out.add(new Map<String, String>{ 'value' => r.Id, 'label' => String.valueOf(r.get('Name')) });
            }
            return out;
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }
}
