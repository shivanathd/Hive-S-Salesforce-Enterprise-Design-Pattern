/**
 * Settings and feature flags from custom metadata, with per-environment overrides.
 *
 *   Integer batchSize = HIVES_Config.getInteger('Orders.BatchSize', 200);
 *   if (HIVES_Config.isEnabled('NewPricing')) { ... }
 *
 * Settings live in HIVES System Property records (Property Name, Value, optional Environment). A
 * record for the current environment wins over one with no environment, so the same deployment can
 * carry production and sandbox values. Feature flags live in HIVES Feature Flag records: on when
 * active, inside the optional date window, and (if a Permission is set) only for users holding that
 * custom permission.
 *
 * Reads use getAll(), which costs no SOQL. Environment-specific records cost one query per transaction.
 */
public inherited sharing class HIVES_Config {

    public enum Environment { PRODUCTION, SANDBOX, SCRATCH }

    @TestVisible static List<HIVES_SystemProperty__mdt> propertyOverride;
    @TestVisible static List<HIVES_FeatureFlag__mdt> flagOverride;
    @TestVisible static Environment environmentOverride;
    private static Environment detected;

    /** PRODUCTION, SANDBOX, or SCRATCH (scratch and trial orgs). */
    public static Environment environment() {
        if (environmentOverride != null) {
            return environmentOverride;
        }
        if (detected == null) {
            // System mode explicitly: from API 67 SOQL defaults to user mode, and most users can't read Organization.
            Organization org = [SELECT IsSandbox, TrialExpirationDate FROM Organization WITH SYSTEM_MODE LIMIT 1];
            // Scratch orgs also report IsSandbox = true; only they (and trials) have an expiry date.
            detected = org.TrialExpirationDate != null ? Environment.SCRATCH
                : org.IsSandbox ? Environment.SANDBOX
                : Environment.PRODUCTION;
        }
        return detected;
    }

    /** The setting's value for this environment, or the default when it is missing or blank. */
    public static String getString(String name, String defaultValue) {
        String general;
        for (HIVES_SystemProperty__mdt p : properties()) {
            if (p.PropertyName__c != name) {
                continue;
            }
            // Detect the environment only when a record needs it, so most reads cost no SOQL.
            if (String.isNotBlank(p.Environment__c) && p.Environment__c == environment().name()) {
                return String.isBlank(p.Value__c) ? defaultValue : p.Value__c.trim();
            }
            if (String.isBlank(p.Environment__c)) {
                general = p.Value__c;
            }
        }
        return String.isBlank(general) ? defaultValue : general.trim();
    }

    /** true only for the text "true" (any case); anything else set is false. */
    public static Boolean getBoolean(String name, Boolean defaultValue) {
        String value = getString(name, null);
        return value == null ? defaultValue : Boolean.valueOf(value);
    }

    public static Integer getInteger(String name, Integer defaultValue) {
        String value = getString(name, null);
        try {
            return value == null ? defaultValue : Integer.valueOf(value);
        } catch (TypeException e) {
            throw new ConfigException('HIVES setting ' + name + ' is not a whole number: ' + value);
        }
    }

    public static Decimal getDecimal(String name, Decimal defaultValue) {
        String value = getString(name, null);
        try {
            return value == null ? defaultValue : Decimal.valueOf(value);
        } catch (TypeException e) {
            throw new ConfigException('HIVES setting ' + name + ' is not a number: ' + value);
        }
    }

    /** Whether a feature is on for the running user right now. Unknown features are off. */
    public static Boolean isEnabled(String feature) {
        Datetime now = System.now();
        for (HIVES_FeatureFlag__mdt f : flags()) {
            if (f.FeatureName__c == feature) {
                return f.IsActive__c
                    && (f.StartDate__c == null || f.StartDate__c <= now)
                    && (f.EndDate__c == null || f.EndDate__c > now)
                    && (String.isBlank(f.Permission__c) || FeatureManagement.checkPermission(f.Permission__c.trim()));
            }
        }
        return false;
    }

    private static List<HIVES_SystemProperty__mdt> properties() {
        return propertyOverride ?? HIVES_SystemProperty__mdt.getAll().values();
    }

    private static List<HIVES_FeatureFlag__mdt> flags() {
        return flagOverride ?? HIVES_FeatureFlag__mdt.getAll().values();
    }

    public class ConfigException extends Exception {}
}
