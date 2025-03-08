/**
 * @description Centralized logging utility for the HIVE-S Framework
 * Provides consistent logging across the application with multiple output options.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public class HIVES_Logger {
    
    /**
     * Available log levels in order of severity (low to high)
     */
    public enum LogLevel {
        DEBUG, INFO, WARN, ERROR, FATAL
    }
    
    /**
     * Source of log entry
     */
    private static final String SOURCE = 'HIVE-S Framework';
    
    /**
     * Log an informational message
     * @param message The message to log
     * @param source The source of the message (class or context)
     */
    public static void info(String message, String source) {
        log(LogLevel.INFO, message, null, source);
    }
    
    /**
     * Log a debug message
     * @param message The message to log
     * @param source The source of the message (class or context)
     */
    public static void debug(String message, String source) {
        log(LogLevel.DEBUG, message, null, source);
    }
    
    /**
     * Log a warning message
     * @param message The message to log
     * @param source The source of the message (class or context)
     */
    public static void warn(String message, String source) {
        log(LogLevel.WARN, message, null, source);
    }
    
    /**
     * Log an error message
     * @param message The message to log
     * @param error The exception related to this error
     * @param source The source of the message (class or context)
     */
    public static void error(String message, Exception error, String source) {
        log(LogLevel.ERROR, message, error, source);
    }
    
    /**
     * Log a fatal error message
     * @param message The message to log
     * @param error The exception related to this error
     * @param source The source of the message (class or context)
     */
    public static void fatal(String message, Exception error, String source) {
        log(LogLevel.FATAL, message, error, source);
    }
    
    /**
     * Main logging method that handles all log entries
     * @param level The severity level of the log
     * @param message The message to log
     * @param error Optional exception related to this log
     * @param source The source of the message (class or context)
     */
    private static void log(LogLevel level, String message, Exception error, String source) {
        // Only log if at or above configured minimum level
        if (!isLoggable(level)) {
            return;
        }
        
        String errorDetails = '';
        if (error != null) {
            errorDetails = ': ' + error.getMessage() + '\n' + error.getStackTraceString();
        }
        
        String sourceValue = String.isBlank(source) ? SOURCE : source;
        String fullMessage = message + errorDetails;
        
        // Log to debug logs
        logToDebug(level, sourceValue, fullMessage);
        
        // Log to custom object if configured and we're not in a test
        if (shouldLogToDB() && !Test.isRunningTest()) {
            logToDB(level, sourceValue, fullMessage);
        }
        
        // Log to platform events if configured
        if (shouldLogToEvents()) {
            logToEvents(level, sourceValue, fullMessage);
        }
    }
    
    /**
     * Check if a log level is loggable based on configuration
     * @param level The level to check
     * @return Boolean Whether the level should be logged
     */
    private static Boolean isLoggable(LogLevel level) {
        LogLevel minLevel = getMinimumLogLevel();
        return level.ordinal() >= minLevel.ordinal();
    }
    
    /**
     * Get the minimum log level from configuration
     * @return LogLevel The minimum level to log
     */
    private static LogLevel getMinimumLogLevel() {
        String configuredLevel = getConfigValue('Logger.MinimumLevel', 'INFO');
        try {
            return LogLevel.valueOf(configuredLevel.toUpperCase());
        } catch (Exception e) {
            // Default to INFO if configuration is invalid
            return LogLevel.INFO;
        }
    }
    
    /**
     * Check if we should log to the database
     * @return Boolean Whether to log to the database
     */
    private static Boolean shouldLogToDB() {
        return Boolean.valueOf(getConfigValue('Logger.LogToDatabase', 'false'));
    }
    
    /**
     * Check if we should log to platform events
     * @return Boolean Whether to log to platform events
     */
    private static Boolean shouldLogToEvents() {
        return Boolean.valueOf(getConfigValue('Logger.LogToPlatformEvents', 'false'));
    }
    
    /**
     * Log to debug logs
     * @param level The severity level
     * @param source The source of the log
     * @param message The message to log
     */
    private static void logToDebug(LogLevel level, String source, String message) {
        String logEntry = Datetime.now().format() + ' [' + level + '] ' + source + ': ' + message;
        
        // Log to appropriate debug level
        switch on level {
            when DEBUG {
                System.debug(LoggingLevel.DEBUG, logEntry);
            }
            when INFO {
                System.debug(LoggingLevel.INFO, logEntry);
            }
            when WARN {
                System.debug(LoggingLevel.WARN, logEntry);
            }
            when ERROR, FATAL {
                System.debug(LoggingLevel.ERROR, logEntry);
            }
        }
    }
    
    /**
     * Log to database custom object
     * @param level The severity level
     * @param source The source of the log
     * @param message The message to log
     */
    private static void logToDB(LogLevel level, String source, String message) {
        try {
            // Create a log record
            // In a real implementation, this would insert to HIVES_AuditLog__c
            // For now, we'll just simulate the operation
            /*
            HIVES_AuditLog__c log = new HIVES_AuditLog__c(
                LogLevel__c = level.name(),
                Source__c = source,
                Message__c = message.left(32000), // Truncate if needed
                EventTime__c = Datetime.now(),
                UserId__c = UserInfo.getUserId()
            );
            insert log;
            */
        } catch (Exception e) {
            // Don't let logging failures cause application failures
            System.debug(LoggingLevel.ERROR, 'Failed to write to log database: ' + e.getMessage());
        }
    }
    
    /**
     * Log to platform events
     * @param level The severity level
     * @param source The source of the log
     * @param message The message to log
     */
    private static void logToEvents(LogLevel level, String source, String message) {
        try {
            // Create and publish a platform event
            // In a real implementation, this would publish HIVES_LogEvent__e
            // For now, we'll just simulate the operation
            /*
            HIVES_LogEvent__e event = new HIVES_LogEvent__e(
                LogLevel__c = level.name(),
                Source__c = source,
                Message__c = message.left(32000), // Truncate if needed
                EventTime__c = Datetime.now(),
                UserId__c = UserInfo.getUserId()
            );
            
            // Publish event
            Database.SaveResult result = EventBus.publish(event);
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Failed to publish log event: ' + result.getErrors()[0].getMessage());
            }
            */
        } catch (Exception e) {
            // Don't let logging failures cause application failures
            System.debug(LoggingLevel.ERROR, 'Failed to publish log event: ' + e.getMessage());
        }
    }
    
    /**
     * Get a configuration value from system properties
     * @param key The property key
     * @param defaultValue The default value if not configured
     * @return String The configured value or default
     */
    private static String getConfigValue(String key, String defaultValue) {
        // In a real implementation, this would query HIVES_SystemProperty__mdt
        // For now, we'll return default values
        return defaultValue;
    }
}
