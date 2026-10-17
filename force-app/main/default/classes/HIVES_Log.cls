/**
 * Logging that survives rollbacks.
 *
 *   HIVES_Log.error('OrderService', 'Could not reserve stock', e);
 *   HIVES_Log.warn('OrderService', 'Price list missing; using standard');
 *
 * Each entry goes to the debug log and, at or above the minimum level, is published as a
 * HIVES_LogEvent__e platform event. The event is set to Publish Immediately, so it is kept even when the
 * transaction that logged it fails and rolls back, which is exactly when you need it. A trigger on the
 * event saves it as a HIVES_Log__c record (view them with the HIVES Log Viewer permission set).
 *
 * Minimum level: system property HIVES.Log.Level (ERROR, WARN, INFO or DEBUG; default WARN).
 * Each published entry uses one of the transaction's 150 DML statements: log failures, not every record.
 */
public without sharing class HIVES_Log {

    public enum Level { ERROR, WARN, INFO, DEBUG }

    public static void error(String source, String message, Exception e) {
        log(Level.ERROR, source, message, e);
    }

    public static void error(String source, String message) {
        log(Level.ERROR, source, message, null);
    }

    public static void warn(String source, String message) {
        log(Level.WARN, source, message, null);
    }

    public static void info(String source, String message) {
        log(Level.INFO, source, message, null);
    }

    public static void debug(String source, String message) {
        log(Level.DEBUG, source, message, null);
    }

    /** Saves published entries as HIVES_Log__c records. Called by HIVES_LogEventTrigger. */
    public static void save(List<HIVES_LogEvent__e> events) {
        List<HIVES_Log__c> logs = new List<HIVES_Log__c>();
        for (HIVES_LogEvent__e e : events) {
            logs.add(new HIVES_Log__c(
                Level__c = e.Level__c, Source__c = e.Source__c, Message__c = e.Message__c,
                StackTrace__c = e.StackTrace__c, RequestId__c = e.RequestId__c, User__c = e.UserId__c
            ));
        }
        insert as system logs;
    }

    private static void log(Level lvl, String source, String message, Exception e) {
        String text = message + (e == null ? '' : '\n' + e.getTypeName() + ': ' + e.getMessage());
        System.debug(lvl == Level.ERROR ? LoggingLevel.ERROR : lvl == Level.WARN ? LoggingLevel.WARN : LoggingLevel.INFO,
            '[' + source + '] ' + text);
        if (lvl.ordinal() > minimum().ordinal()) {
            return;
        }
        HIVES_LogEvent__e event = new HIVES_LogEvent__e(
            Level__c = lvl.name(),
            Source__c = source?.left(255),
            Message__c = text.left(32768),
            StackTrace__c = e?.getStackTraceString()?.left(32768),
            RequestId__c = Request.getCurrent().getRequestId(),
            UserId__c = UserInfo.getUserId()
        );
        Database.SaveResult result = EventBus.publish(event);
        if (!result.isSuccess()) {
            System.debug(LoggingLevel.ERROR, 'HIVES_Log could not publish: ' + result.getErrors()[0].getMessage());
        }
    }

    private static Level minimum() {
        String configured = HIVES_Config.getString('HIVES.Log.Level', 'WARN').toUpperCase();
        for (Level l : Level.values()) {
            if (l.name() == configured) {
                return l;
            }
        }
        return Level.WARN;
    }
}
