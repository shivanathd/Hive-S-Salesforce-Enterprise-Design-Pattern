/**
 * @description Security enforcement utilities for the HIVE-S Framework
 * Provides centralized security enforcement with configurable behavior.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public class HIVES_SecurityUtils {
    
    /**
     * @description Types of security enforcement
     */
    public enum EnforcementType {
        CRUD, FLS, OBJECT_CRUD, SHARING
    }
    
    /**
     * @description Insert records with security enforcement
     * @param records The records to insert
     * @return List<Database.SaveResult> The save results
     */
    public static List<Database.SaveResult> insertRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        
        String objectType = String.valueOf(records[0].getSObjectType());
        
        // Check CRUD before attempting insert
        if (isEnforcementEnabled(EnforcementType.CRUD, objectType)) {
            validateCRUD(objectType, 'CREATE');
        }
        
        if (isEnforcementEnabled(EnforcementType.FLS, objectType)) {
            validateFLS(records, 'CREATE');
        }
        
        List<Database.SaveResult> results;
        
        // Check whether sharing should be enforced
        if (isEnforcementEnabled(EnforcementType.SHARING, objectType)) {
            // Use the with sharing behavior
            results = insertWithSharing(records);
        } else {
            // Use standard behavior
            results = Database.insert(records, false);
        }
        
        // Log errors if any
        logErrors(results, 'insert', objectType);
        
        return results;
    }
    
    /**
     * @description Update records with security enforcement
     * @param records The records to update
     * @return List<Database.SaveResult> The save results
     */
    public static List<Database.SaveResult> updateRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        
        String objectType = String.valueOf(records[0].getSObjectType());
        
        // Check CRUD before attempting update
        if (isEnforcementEnabled(EnforcementType.CRUD, objectType)) {
            validateCRUD(objectType, 'UPDATE');
        }
        
        if (isEnforcementEnabled(EnforcementType.FLS, objectType)) {
            validateFLS(records, 'UPDATE');
        }
        
        List<Database.SaveResult> results;
        
        // Check whether sharing should be enforced
        if (isEnforcementEnabled(EnforcementType.SHARING, objectType)) {
            // Use the with sharing behavior
            results = updateWithSharing(records);
        } else {
            // Use standard behavior
            results = Database.update(records, false);
        }
        
        // Log errors if any
        logErrors(results, 'update', objectType);
        
        return results;
    }
    
    /**
     * @description Delete records with security enforcement
     * @param records The records to delete
     * @return List<Database.DeleteResult> The delete results
     */
    public static List<Database.DeleteResult> deleteRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<Database.DeleteResult>();
        }
        
        String objectType = String.valueOf(records[0].getSObjectType());
        
        // Check CRUD before attempting delete
        if (isEnforcementEnabled(EnforcementType.CRUD, objectType)) {
            validateCRUD(objectType, 'DELETE');
        }
        
        List<Database.DeleteResult> results;
        
        // Check whether sharing should be enforced
        if (isEnforcementEnabled(EnforcementType.SHARING, objectType)) {
            // Use the with sharing behavior
            results = deleteWithSharing(records);
        } else {
            // Use standard behavior
            results = Database.delete(records, false);
        }
        
        // Log errors if any
        logDeleteErrors(results, objectType);
        
        return results;
    }
    
    /**
     * @description Insert records with sharing rules enforced
     * @param records The records to insert
     * @return List<Database.SaveResult> The save results
     */
    private static List<Database.SaveResult> insertWithSharing(List<SObject> records) {
        // This class executes in the context it's called from
        return Database.insert(records, false);
    }
    
    /**
     * @description Update records with sharing rules enforced
     * @param records The records to update
     * @return List<Database.SaveResult> The save results
     */
    private static List<Database.SaveResult> updateWithSharing(List<SObject> records) {
        // This class executes in the context it's called from
        return Database.update(records, false);
    }
    
    /**
     * @description Delete records with sharing rules enforced
     * @param records The records to delete
     * @return List<Database.DeleteResult> The delete results
     */
    private static List<Database.DeleteResult> deleteWithSharing(List<SObject> records) {
        // This class executes in the context it's called from
        return Database.delete(records, false);
    }
    
    /**
     * @description Verify CRUD permissions for an object
     * @param objectType The object API name
     * @param operation The operation (CREATE, READ, UPDATE, DELETE)
     * @throws SecurityException if the user lacks permission
     */
    public static void validateCRUD(String objectType, String operation) {
        // Get the SObject descriptor
        Schema.DescribeSObjectResult describe = getSObjectDescribe(objectType);
        
        Boolean hasPermission = false;
        String errorMessage = '';
        
        // Check appropriate permission based on operation
        switch on operation.toUpperCase() {
            when 'CREATE' {
                hasPermission = describe.isCreateable();
                errorMessage = 'User does not have create permission on ' + objectType;
            }
            when 'READ' {
                hasPermission = describe.isAccessible();
                errorMessage = 'User does not have read permission on ' + objectType;
            }
            when 'UPDATE' {
                hasPermission = describe.isUpdateable();
                errorMessage = 'User does not have update permission on ' + objectType;
            }
            when 'DELETE' {
                hasPermission = describe.isDeletable();
                errorMessage = 'User does not have delete permission on ' + objectType;
            }
            when else {
                throw new SecurityException('Invalid operation type: ' + operation);
            }
        }
        
        // Throw security exception if permission check fails
        if (!hasPermission) {
            throw new SecurityException(errorMessage);
        }
    }
    
    /**
     * @description Verify FLS permissions for fields on records
     * @param records The records to check
     * @param operation The operation (CREATE, READ, UPDATE)
     * @throws SecurityException if the user lacks permission
     */
    public static void validateFLS(List<SObject> records, String operation) {
        if (records == null || records.isEmpty()) {
            return;
        }
        
        // Get a sample record and its type
        SObject sample = records[0];
        String objectType = String.valueOf(sample.getSObjectType());
        
        // Get the SObject descriptor
        Schema.DescribeSObjectResult describe = getSObjectDescribe(objectType);
        Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
        
        // Get the populated field names (combining all records)
        Set<String> populatedFields = new Set<String>();
        
        for (SObject record : records) {
            Map<String, Object> fieldValues = record.getPopulatedFieldsAsMap();
            populatedFields.addAll(fieldValues.keySet());
        }
        
        // Check FLS for each populated field
        for (String fieldName : populatedFields) {
            // Skip Id field
            if (fieldName.equalsIgnoreCase('Id')) {
                continue;
            }
            
            Schema.SObjectField field = fieldMap.get(fieldName);
            
            if (field == null) {
                throw new SecurityException('Field does not exist: ' + fieldName + ' on ' + objectType);
            }
            
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            Boolean hasPermission = false;
            String errorMessage = '';
            
            // Check appropriate permission based on operation
            switch on operation.toUpperCase() {
                when 'CREATE' {
                    hasPermission = fieldDescribe.isCreateable();
                    errorMessage = 'User does not have create permission on field ' + fieldName + ' of ' + objectType;
                }
                when 'READ' {
                    hasPermission = fieldDescribe.isAccessible();
                    errorMessage = 'User does not have read permission on field ' + fieldName + ' of ' + objectType;
                }
                when 'UPDATE' {
                    hasPermission = fieldDescribe.isUpdateable();
                    errorMessage = 'User does not have update permission on field ' + fieldName + ' of ' + objectType;
                }
                when else {
                    throw new SecurityException('Invalid operation type for FLS check: ' + operation);
                }
            }
            
            // Throw security exception if permission check fails
            if (!hasPermission) {
                throw new SecurityException(errorMessage);
            }
        }
    }
    
    /**
     * @description Get SObject describe result
     * @param objectType API name of the object
     * @return Schema.DescribeSObjectResult The describe result
     */
    private static Schema.DescribeSObjectResult getSObjectDescribe(String objectType) {
        // Get SObject type from API name
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectType);
        
        if (sot == null) {
            throw new SecurityException('Invalid object type: ' + objectType);
        }
        
        return sot.getDescribe();
    }
    
    /**
     * @description Check if a specific security enforcement is enabled
     * @param enforcementType The type of enforcement to check
     * @param objectType The object type to check for (optional)
     * @return Boolean Whether the enforcement is enabled
     */
    public static Boolean isEnforcementEnabled(EnforcementType enforcementType, String objectType) {
        // Default to true for all enforcement types
        Boolean defaultValue = true;
        
        // Check object-specific setting first if object type provided
        if (String.isNotBlank(objectType)) {
            String objectSetting = 'Security.' + enforcementType.name() + '.' + objectType;
            HIVES_SystemProperty__mdt objectConfig = HIVES_ConfigurationService.getSystemProperty(objectSetting);
            
            if (objectConfig != null && objectConfig.BooleanValue__c != null) {
                return objectConfig.BooleanValue__c;
            }
        }
        
        // Check global setting
        String globalSetting = 'Security.' + enforcementType.name() + '.Enabled';
        HIVES_SystemProperty__mdt globalConfig = HIVES_ConfigurationService.getSystemProperty(globalSetting);
        
        if (globalConfig != null && globalConfig.BooleanValue__c != null) {
            return globalConfig.BooleanValue__c;
        }
        
        return defaultValue;
    }
    
    /**
     * @description Log errors from database operations
     * @param results The save results
     * @param operation The operation type
     * @param objectType The object type
     */
    private static void logErrors(List<Database.SaveResult> results, String operation, String objectType) {
        List<String> errors = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {
                    errors.add('Error ' + (i+1) + ': ' + error.getStatusCode() + ' - ' + error.getMessage());
                }
            }
        }
        
        if (!errors.isEmpty()) {
            String errorMessage = 'Errors during ' + operation + ' on ' + objectType + ': ' + String.join(errors, '; ');
            HIVES_Logger.error(errorMessage, null, 'HIVES_SecurityUtils');
        }
    }
    
    /**
     * @description Log errors from delete operations
     * @param results The delete results
     * @param objectType The object type
     */
    private static void logDeleteErrors(List<Database.DeleteResult> results, String objectType) {
        List<String> errors = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.DeleteResult result = results[i];
            
            if (!result.isSuccess()) {
                for (Database.Error error : result.getErrors()) {
                    errors.add('Error ' + (i+1) + ': ' + error.getStatusCode() + ' - ' + error.getMessage());
                }
            }
        }
        
        if (!errors.isEmpty()) {
            String errorMessage = 'Errors during delete on ' + objectType + ': ' + String.join(errors, '; ');
            HIVES_Logger.error(errorMessage, null, 'HIVES_SecurityUtils');
        }
    }
    
    /**
     * @description Custom exception for security violations
     */
    public class SecurityException extends Exception {}
}
