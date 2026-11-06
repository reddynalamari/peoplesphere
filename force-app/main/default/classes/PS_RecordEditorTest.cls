@IsTest
private class PS_RecordEditorTest {

    @TestSetup
    static void setup() {
        PS_TestFactory.world();
    }

    @IsTest
    static void describeEveryObject() {
        Test.startTest();
        for (String api : PS_DataExplorerController.OBJECTS) {
            Map<String, Object> d = PS_RecordEditorController.describeObject(api);
            System.assertNotEquals(null, d.get('fields'), api);
        }
        Test.stopTest();
        try { PS_RecordEditorController.describeObject('Account'); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
    }

    @IsTest
    static void createViewEditDelete() {
        Organization__c org = [SELECT Id FROM Organization__c LIMIT 1];
        Test.startTest();
        Id deptId = PS_RecordEditorController.saveRecord('Department__c', null,
            JSON.serialize(new Map<String, Object>{ 'Name' => 'Legal', 'Code__c' => 'LEG', 'Organization__c' => org.Id, 'Active__c' => true, 'Headcount_Budget__c' => '4' }));
        Department__c dept = [SELECT Name, Code__c, Headcount_Budget__c, Active__c FROM Department__c WHERE Id = :deptId];
        System.assertEquals('LEG', dept.Code__c);
        System.assertEquals(4, dept.Headcount_Budget__c);

        Id empId = PS_RecordEditorController.saveRecord('Employee__c', null, JSON.serialize(new Map<String, Object>{
            'Name' => 'Lena Legal', 'Department__c' => deptId, 'Status__c' => 'Active', 'Date_of_Joining__c' => '2026-01-15',
            'Work_Email__c' => 'lena@example.com', 'Annual_CTC__c' => 900000 }));
        System.assert([SELECT Employee_ID__c FROM Employee__c WHERE Id = :empId].Employee_ID__c != null, 'trigger ran');

        PS_RecordEditorController.saveRecord('Employee__c', empId, JSON.serialize(new Map<String, Object>{ 'Phone__c' => '+91 1', 'Critical_Role__c' => true, 'Exit_Date__c' => '' }));
        System.assertEquals('+91 1', [SELECT Phone__c FROM Employee__c WHERE Id = :empId].Phone__c);

        Map<String, Object> view = PS_RecordEditorController.getRecord('Department__c', deptId);
        System.assertEquals('Legal', view.get('name'));
        System.assert(!((List<Object>) view.get('related')).isEmpty());
        System.assertNotEquals(null, PS_RecordEditorController.getRecord('Employee__c', empId));

        System.assert(PS_RecordEditorController.searchLookup('Department__c', 'Leg').size() == 1);
        System.assert(PS_RecordEditorController.searchLookup('User', '').size() >= 1);

        PS_RecordEditorController.saveRecord('HR_Ticket__c', null, JSON.serialize(new Map<String, Object>{ 'Subject__c' => 'Test', 'Employee__c' => empId }));
        Id holidayId = PS_RecordEditorController.saveRecord('Holiday__c', null, JSON.serialize(new Map<String, Object>{ 'Name' => 'Test day', 'Holiday_Date__c' => '2027-02-02' }));
        PS_RecordEditorController.deleteRecord('Holiday__c', holidayId);
        System.assertEquals(0, [SELECT COUNT() FROM Holiday__c WHERE Id = :holidayId]);
        try { PS_RecordEditorController.deleteRecord('Department__c', empId); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        try { PS_RecordEditorController.saveRecord('Department__c', null, '{"Bogus__c": 1}'); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
        Test.stopTest();
    }

    @IsTest
    static void conversions() {
        Schema.DescribeFieldResult dt = Interview__c.Scheduled_At__c.getDescribe();
        System.assertNotEquals(null, PS_RecordEditorController.convert(dt, '2026-11-07T10:00:00.000Z'));
        System.assertEquals(3, PS_RecordEditorController.convert(Quiz_Question__c.Points__c.getDescribe(), '3'));
        System.assertEquals(false, PS_RecordEditorController.convert(Employee__c.Critical_Role__c.getDescribe(), null));
        System.assertEquals(true, PS_RecordEditorController.convert(Employee__c.Critical_Role__c.getDescribe(), 'true'));
    }

    @IsTest
    static void gatewayEditorRequiresPassword() {
        String t = PS_GuestHrGateway.unlock('admin123');
        Organization__c org = [SELECT Id FROM Organization__c LIMIT 1];
        System.assertNotEquals(null, PS_GuestHrGateway.describeObject('Location__c', t));
        Id locId = PS_GuestHrGateway.saveRecord('Location__c', null, JSON.serialize(new Map<String, Object>{ 'Name' => 'Chennai', 'Organization__c' => org.Id }), t);
        System.assertNotEquals(null, PS_GuestHrGateway.getRecord('Location__c', locId, t));
        System.assert(!PS_GuestHrGateway.searchLookup('Location__c', 'Chen', t).isEmpty());
        PS_GuestHrGateway.deleteRecord('Location__c', locId, t);
        try { PS_GuestHrGateway.saveRecord('Location__c', null, '{"Name":"X"}', null); System.assert(false); } catch (AuraHandledException e) { System.assert(true); }
    }
}
