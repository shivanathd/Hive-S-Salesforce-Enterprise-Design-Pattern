/**
 * Runs the configured handlers for the current trigger. Every trigger is one line:
 *
 *   trigger AccountTrigger on Account (before insert, before update, before delete,
 *           after insert, after update, after delete, after undelete) {
 *       HIVES_Trigger.run();
 *   }
 *
 *   trigger ─▶ HIVES_Trigger.run ─▶ active HIVES Trigger Handler records for the object, by Execution Order
 *                                     ├─ skip: HIVES_Bypass_All_Triggers, handler's Bypass Permission, bypass(Type)
 *                                     ├─ skip: already running for this object and event (unless Allow Recursion)
 *                                     └─ handler.handle(context, access mode) ── throws? log (survives rollback), rethrow
 *
 * Handlers that throw are never swallowed: the error is logged through HIVES_Log and the exception
 * propagates, so the save fails visibly. Use addError on records for validation messages.
 */
public without sharing class HIVES_Trigger {

    public static final String BYPASS_ALL_PERMISSION = 'HIVES_Bypass_All_Triggers';

    @TestVisible static List<HIVES_TriggerConfiguration__mdt> configOverride;
    private static final Set<String> BYPASSED = new Set<String>();
    private static final Map<String, Integer> RUNNING = new Map<String, Integer>(); // handler|object|event -> nesting depth

    public static void run() {
        run(new HIVES_TriggerContext(Trigger.operationType, Trigger.new, Trigger.oldMap));
    }

    /** Runs handlers for a given context. Public so tests can drive the dispatcher without DML. */
    public static void run(HIVES_TriggerContext context) {
        if (FeatureManagement.checkPermission(BYPASS_ALL_PERMISSION)) {
            return;
        }
        for (HIVES_TriggerConfiguration__mdt config : handlersFor(context.sObjectType)) {
            if (isBypassed(config)) {
                continue;
            }
            // Depth guard: a handler doesn't re-enter itself (e.g. an after-update handler updating
            // its own object). It resets when the handler returns, so partial-success retries and
            // later 200-record chunks still run.
            String key = config.HandlerClass__c.trim().toLowerCase() + '|' + context.sObjectType + '|' + context.operation;
            Integer depth = RUNNING.get(key) ?? 0;
            if (depth > 0 && !config.AllowRecursion__c) {
                HIVES_Log.debug('HIVES_Trigger', 'Skipped re-entry of ' + key + '; set Allow Recursion to run it');
                continue;
            }
            HIVES_TriggerHandler handler = instantiate(config);
            RUNNING.put(key, depth + 1);
            try {
                handler.handle(context, config.AccessMode__c == 'User' ? System.AccessLevel.USER_MODE : System.AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                HIVES_Log.error(config.HandlerClass__c, context.sObjectType + ' ' + context.operation + ' failed', e);
                throw e;
            } finally {
                RUNNING.put(key, depth);
            }
        }
    }

    /** Skips a handler for the rest of this transaction, for example while loading data in Apex. */
    public static void bypass(Type handler) {
        BYPASSED.add(handler.getName().toLowerCase());
    }

    public static void clearBypass(Type handler) {
        BYPASSED.remove(handler.getName().toLowerCase());
    }

    public static void clearAllBypasses() {
        BYPASSED.clear();
    }

    /** Active handler records for an object, in Execution Order (then class name). */
    public static List<HIVES_TriggerConfiguration__mdt> handlersFor(SObjectType objectType) {
        String objectName = String.valueOf(objectType);
        List<HIVES_TriggerConfiguration__mdt> result = new List<HIVES_TriggerConfiguration__mdt>();
        for (HIVES_TriggerConfiguration__mdt c : allConfigs()) {
            if (c.IsActive__c && c.Object__c?.trim() == objectName) {
                result.add(c);
            }
        }
        result.sort(new ByOrder());
        return result;
    }

    /** Creates the handler a record names, checking the class exists and extends HIVES_TriggerHandler first. */
    public static HIVES_TriggerHandler instantiate(HIVES_TriggerConfiguration__mdt config) {
        String record = label(config);
        Type handlerType = Type.forName(config.HandlerClass__c?.trim());
        if (handlerType == null) {
            throw new ConfigException(record + 'class ' + config.HandlerClass__c + ' does not exist or is not visible.');
        }
        if (!HIVES_TriggerHandler.class.isAssignableFrom(handlerType)) {
            throw new ConfigException(record + config.HandlerClass__c + ' does not extend HIVES_TriggerHandler.');
        }
        return (HIVES_TriggerHandler) handlerType.newInstance();
    }

    /**
     * Everything wrong with the HIVES Trigger Handler records, active or not: unknown objects, missing
     * classes, classes that don't extend HIVES_TriggerHandler. Empty when all is well.
     * HIVES_ConfigurationCheckTest asserts this is empty, so a broken record fails the deploy, not a save.
     */
    public static List<String> configurationProblems() {
        List<String> problems = new List<String>();
        Map<String, SObjectType> objects = Schema.getGlobalDescribe();
        for (HIVES_TriggerConfiguration__mdt c : allConfigs()) {
            if (String.isBlank(c.Object__c) || !objects.containsKey(c.Object__c.trim().toLowerCase())) {
                problems.add(label(c) + 'unknown object ' + c.Object__c);
            }
            try {
                instantiate(c);
            } catch (ConfigException e) {
                problems.add(e.getMessage());
            }
        }
        return problems;
    }

    private static Boolean isBypassed(HIVES_TriggerConfiguration__mdt config) {
        return BYPASSED.contains(config.HandlerClass__c.trim().toLowerCase())
            || (String.isNotBlank(config.BypassPermission__c) && FeatureManagement.checkPermission(config.BypassPermission__c.trim()));
    }

    private static List<HIVES_TriggerConfiguration__mdt> allConfigs() {
        return configOverride ?? HIVES_TriggerConfiguration__mdt.getAll().values();
    }

    private static String label(HIVES_TriggerConfiguration__mdt config) {
        return 'HIVES Trigger Handler "' + config.DeveloperName + '": ';
    }

    private class ByOrder implements System.Comparator<HIVES_TriggerConfiguration__mdt> {
        public Integer compare(HIVES_TriggerConfiguration__mdt a, HIVES_TriggerConfiguration__mdt b) {
            Decimal diff = (a.ExecutionOrder__c ?? 0) - (b.ExecutionOrder__c ?? 0);
            return diff < 0 ? -1 : diff > 0 ? 1 : a.HandlerClass__c.compareTo(b.HandlerClass__c);
        }
    }

    public class ConfigException extends Exception {}
}
