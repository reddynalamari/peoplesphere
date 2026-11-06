/**
 * Organizational hierarchy for lightning-tree, built from Manager__c.
 */
public inherited sharing class PS_OrgChartController {

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getOrgTree(Id departmentId) {
        try {
            List<Employee__c> emps = departmentId == null
                ? [SELECT Id, Name, Manager__c, Designation__r.Name, Department__r.Name, Status__c FROM Employee__c
                   WHERE Status__c IN :PS_Util.ACTIVE_STATUSES ORDER BY Name LIMIT 3000]
                : [SELECT Id, Name, Manager__c, Designation__r.Name, Department__r.Name, Status__c FROM Employee__c
                   WHERE Status__c IN :PS_Util.ACTIVE_STATUSES AND Department__c = :departmentId ORDER BY Name LIMIT 3000];
            Map<Id, Employee__c> byId = new Map<Id, Employee__c>(emps);
            Map<Id, List<Employee__c>> children = new Map<Id, List<Employee__c>>();
            List<Employee__c> roots = new List<Employee__c>();
            for (Employee__c e : emps) {
                if (e.Manager__c == null || !byId.containsKey(e.Manager__c)) { roots.add(e); continue; }
                if (!children.containsKey(e.Manager__c)) children.put(e.Manager__c, new List<Employee__c>());
                children.get(e.Manager__c).add(e);
            }
            List<Map<String, Object>> items = new List<Map<String, Object>>();
            for (Employee__c r : roots) items.add(node(r, children, 0));
            List<Map<String, Object>> depts = new List<Map<String, Object>>();
            for (Department__c d : [SELECT Id, Name FROM Department__c WHERE Active__c = true ORDER BY Name]) {
                depts.add(new Map<String, Object>{ 'label' => d.Name, 'value' => d.Id });
            }
            Integer maxSpan = 0;
            for (List<Employee__c> c : children.values()) maxSpan = Math.max(maxSpan, c.size());
            return new Map<String, Object>{ 'items' => items, 'departments' => depts, 'total' => emps.size(),
                'managers' => children.size(), 'maxSpan' => maxSpan };
        } catch (Exception e) {
            throw PS_Util.auraError(e);
        }
    }

    private static Map<String, Object> node(Employee__c e, Map<Id, List<Employee__c>> children, Integer depth) {
        List<Map<String, Object>> kids = new List<Map<String, Object>>();
        if (children.containsKey(e.Id) && depth < 15) {
            for (Employee__c c : children.get(e.Id)) kids.add(node(c, children, depth + 1));
        }
        String meta = (e.Designation__r?.Name == null ? '' : e.Designation__r.Name) + (e.Department__r?.Name == null ? '' : ' · ' + e.Department__r.Name);
        if (!kids.isEmpty()) meta += ' · ' + kids.size() + ' direct report' + (kids.size() == 1 ? '' : 's');
        return new Map<String, Object>{ 'label' => e.Name, 'name' => e.Id, 'metatext' => meta, 'expanded' => depth < 2, 'items' => kids };
    }
}
