/**
 * @description Service for accessing configuration from custom metadata
 * Provides a centralized way to access system properties and feature flags
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public class HIVES_ConfigurationService {
    
    // Cache for system properties to avoid repeated queries
    private static Map<String, HIVES_SystemProperty__mdt> systemPropertyCache = new Map<String, HIVES_SystemProperty__mdt>();
    
    // Cache for feature flags to avoid repeated queries
    private static Map<String, HIVES_FeatureFlag__mdt> featureFlagCache = new Map<String, HIVES_FeatureFlag__mdt>();
    
    // Environment detection
    private static String currentEnvironment;
    
    /**
     * @description Get a system property by its name
     * @param propertyName The name of the property to retrieve
     * @return HIVES_SystemProperty__mdt The property if found, null otherwise
     */
    public static HIVES_SystemProperty__mdt getSystemProperty(String propertyName) {
        // Check cache first
        if (systemPropertyCache.containsKey(propertyName)) {
            return systemPropertyCache.get(propertyName);
        }
        
        String environment = getCurrentEnvironment();
        
        // Query for property specific to this environment
        List<HIVES_SystemProperty__mdt> properties = [
            SELECT PropertyName__c, StringValue__c, NumberValue__c, BooleanValue__c, Environment__c
            FROM HIVES_SystemProperty__mdt
            WHERE PropertyName__c = :propertyName
            AND (Environment__c = :environment OR Environment__c = null)
            ORDER BY Environment__c NULLS LAST
            LIMIT 1
        ];
        
        // If found, cache and return
        if (!properties.isEmpty()) {
            HIVES_SystemProperty__mdt property = properties[0];
            systemPropertyCache.put(propertyName, property);
            return property;
        }
        
        // Not found
        return null;
    }
    
    /**
     * @description Get a string value from system properties
     * @param propertyName The name of the property
     * @param defaultValue Default value to return if property not found
     * @return String The property value or default
     */
    public static String getStringProperty(String propertyName, String defaultValue) {
        HIVES_SystemProperty__mdt property = getSystemProperty(propertyName);
        
        if (property != null && property.StringValue__c != null) {
            return property.StringValue__c;
        }
        
        return defaultValue;
    }
    
    /**
     * @description Get a number value from system properties
     * @param propertyName The name of the property
     * @param defaultValue Default value to return if property not found
     * @return Decimal The property value or default
     */
    public static Decimal getNumberProperty(String propertyName, Decimal defaultValue) {
        HIVES_SystemProperty__mdt property = getSystemProperty(propertyName);
        
        if (property != null && property.NumberValue__c != null) {
            return property.NumberValue__c;
        }
        
        return defaultValue;
    }
    
    /**
     * @description Get a boolean value from system properties
     * @param propertyName The name of the property
     * @param defaultValue Default value to return if property not found
     * @return Boolean The property value or default
     */
    public static Boolean getBooleanProperty(String propertyName, Boolean defaultValue) {
        HIVES_SystemProperty__mdt property = getSystemProperty(propertyName);
        
        if (property != null && property.BooleanValue__c != null) {
            return property.BooleanValue__c;
        }
        
        return defaultValue;
    }
    
    /**
     * @description Check if a feature is enabled
     * @param featureName The name of the feature to check
     * @return Boolean Whether the feature is enabled
     */
    public static Boolean isFeatureEnabled(String featureName) {
        // Check cache first
        if (featureFlagCache.containsKey(featureName)) {
            return isFeatureActive(featureFlagCache.get(featureName));
        }
        
        // Query for the feature flag
        List<HIVES_FeatureFlag__mdt> features = [
            SELECT FeatureName__c, IsActive__c, StartDate__c, EndDate__c
            FROM HIVES_FeatureFlag__mdt
            WHERE FeatureName__c = :featureName
            LIMIT 1
        ];
        
        // If found, cache and check if active
        if (!features.isEmpty()) {
            HIVES_FeatureFlag__mdt feature = features[0];
            featureFlagCache.put(featureName, feature);
            return isFeatureActive(feature);
        }
        
        // Default to disabled if not found
        return false;
    }
    
    /**
     * @description Check if a feature is active based on its configuration
     * @param feature The feature flag record
     * @return Boolean Whether the feature is active
     */
    private static Boolean isFeatureActive(HIVES_FeatureFlag__mdt feature) {
        // Not active at all
        if (!feature.IsActive__c) {
            return false;
        }
        
        Datetime now = Datetime.now();
        
        // Check start date
        if (feature.StartDate__c != null && feature.StartDate__c > now) {
            return false;
        }
        
        // Check end date
        if (feature.EndDate__c != null && feature.EndDate__c < now) {
            return false;
        }
        
        // All checks passed
        return true;
    }
    
    /**
     * @description Get the current environment
     * @return String The current environment code (DEV, QA, UAT, PROD)
     */
    public static String getCurrentEnvironment() {
        if (currentEnvironment != null) {
            return currentEnvironment;
        }
        
        // In a real implementation, this would determine the environment
        // based on org ID, custom setting, etc.
        
        // For now, assume we're in a dev environment
        currentEnvironment = 'DEV';
        return currentEnvironment;
    }
    
    /**
     * @description Set the current environment (for testing)
     * @param environment The environment code to set
     */
    @TestVisible
    private static void setCurrentEnvironment(String environment) {
        currentEnvironment = environment;
    }
    
    /**
     * @description Clear the configuration caches (for testing)
     */
    @TestVisible
    private static void clearCaches() {
        systemPropertyCache.clear();
        featureFlagCache.clear();
    }
}
