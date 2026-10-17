/**
 * Test fixtures. Custom metadata records can't be inserted in tests, so configuration is built in
 * memory and injected through the @TestVisible overrides on HIVES_Trigger and HIVES_Config.
 */
@isTest
public class HIVES_TestData {

    public static HIVES_TriggerConfiguration__mdt handler(String handlerClass, String objectName, Integer order) {
        return (HIVES_TriggerConfiguration__mdt) build(new Map<String, Object>{
            'DeveloperName' => handlerClass.replace('.', '_'), 'HandlerClass__c' => handlerClass,
            'Object__c' => objectName, 'ExecutionOrder__c' => order, 'IsActive__c' => true,
            'AccessMode__c' => 'System', 'AllowRecursion__c' => false
        }, HIVES_TriggerConfiguration__mdt.class);
    }

    /** Copy of a custom metadata record with one field changed. */
    public static SObject with(SObject record, String field, Object value) {
        Map<String, Object> values = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(record));
        values.remove('attributes');
        values.put(field, value);
        return build(values, Type.forName(String.valueOf(record.getSObjectType())));
    }

    public static void useHandlers(List<HIVES_TriggerConfiguration__mdt> configs) {
        HIVES_Trigger.configOverride = configs;
    }

    public static HIVES_SystemProperty__mdt property(String name, String value, String environment) {
        return (HIVES_SystemProperty__mdt) build(new Map<String, Object>{
            'DeveloperName' => 'P' + Math.abs(Crypto.getRandomInteger()), 'PropertyName__c' => name,
            'Value__c' => value, 'Environment__c' => environment
        }, HIVES_SystemProperty__mdt.class);
    }

    public static HIVES_FeatureFlag__mdt flag(String feature, Boolean active, Datetime startDate, Datetime endDate, String permission) {
        return (HIVES_FeatureFlag__mdt) build(new Map<String, Object>{
            'DeveloperName' => feature, 'FeatureName__c' => feature, 'IsActive__c' => active,
            'StartDate__c' => startDate, 'EndDate__c' => endDate, 'Permission__c' => permission
        }, HIVES_FeatureFlag__mdt.class);
    }

    /** A user with the given profile, inserted without a mixed DML error. */
    public static User user(String profileName, String permissionSet) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
            u = new User(
                LastName = 'HIVES Test', Alias = 'hv' + unique.left(6), Email = 'hives' + unique + '@example.com',
                Username = 'hives' + unique + '@example.com.test', ProfileId = p.Id,
                TimeZoneSidKey = 'Asia/Kolkata', LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
            );
            insert u;
            if (permissionSet != null) {
                insert new PermissionSetAssignment(AssigneeId = u.Id,
                    PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permissionSet].Id);
            }
        }
        return u;
    }

    private static SObject build(Map<String, Object> values, Type recordType) {
        return (SObject) JSON.deserialize(JSON.serialize(values), recordType);
    }
}
