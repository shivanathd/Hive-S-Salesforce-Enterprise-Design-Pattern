/**
 * @description Utility for monitoring and managing Salesforce governor limits
 * Provides proactive detection of approaching governor limits.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public class HIVES_LimitMonitor {

    // Default threshold percentages
    private static final Integer DEFAULT_THRESHOLD_PERCENTAGE = 75;
    
    // Warning types
    public enum LimitType {
        SOQL_QUERIES,
        SOQL_ROWS,
        DML_OPERATIONS,
        DML_ROWS,
        CPU_TIME,
        HEAP_SIZE
    }
    
    /**
     * @description Check all monitored limits and log warnings if thresholds are exceeded
     */
    public static void checkLimits() {
        // Only check if monitoring is enabled
        if (!isLimitMonitoringEnabled()) {
            return;
        }
        
        checkSOQLQueries();
        checkSOQLRows();
        checkDMLOperations();
        checkDMLRows();
        checkCPUTime();
        checkHeapSize();
    }
    
    /**
     * @description Check if limit monitoring is enabled in configuration
     * @return Boolean Whether limit monitoring is enabled
     */
    private static Boolean isLimitMonitoringEnabled() {
        return HIVES_ConfigurationService.getBooleanProperty('LimitMonitoring.Enabled', true);
    }
    
    /**
     * @description Get the threshold percentage for a specific limit type
     * @param limitType The type of limit to get threshold for
     * @return Integer The threshold percentage (0-100)
     */
    private static Integer getThresholdPercentage(LimitType limitType) {
        String configKey = 'LimitMonitoring.Threshold.' + limitType.name();
        return (Integer)HIVES_ConfigurationService.getNumberProperty(configKey, DEFAULT_THRESHOLD_PERCENTAGE);
    }
    
    /**
     * @description Check SOQL query limits
     */
    private static void checkSOQLQueries() {
        Integer threshold = getThresholdPercentage(LimitType.SOQL_QUERIES);
        Integer used = Limits.getQueries();
        Integer max = Limits.getLimitQueries();
        Integer percentUsed = (used * 100) / max;
        
        if (percentUsed >= threshold) {
            logLimitWarning(LimitType.SOQL_QUERIES, used, max, percentUsed);
        }
    }
    
    /**
     * @description Check SOQL row limits
     */
    private static void checkSOQLRows() {
        Integer threshold = getThresholdPercentage(LimitType.SOQL_ROWS);
        Integer used = Limits.getQueryRows();
        Integer max = Limits.getLimitQueryRows();
        Integer percentUsed = (used * 100) / max;
        
        if (percentUsed >= threshold) {
            logLimitWarning(LimitType.SOQL_ROWS, used, max, percentUsed);
        }
    }
    
    /**
     * @description Check DML operation limits
     */
    private static void checkDMLOperations() {
        Integer threshold = getThresholdPercentage(LimitType.DML_OPERATIONS);
        Integer used = Limits.getDmlStatements();
        Integer max = Limits.getLimitDmlStatements();
        Integer percentUsed = (used * 100) / max;
        
        if (percentUsed >= threshold) {
            logLimitWarning(LimitType.DML_OPERATIONS, used, max, percentUsed);
        }
    }
    
    /**
     * @description Check DML row limits
     */
    private static void checkDMLRows() {
        Integer threshold = getThresholdPercentage(LimitType.DML_ROWS);
        Integer used = Limits.getDmlRows();
        Integer max = Limits.getLimitDmlRows();
        Integer percentUsed = (used * 100) / max;
        
        if (percentUsed >= threshold) {
            logLimitWarning(LimitType.DML_ROWS, used, max, percentUsed);
        }
    }
    
    /**
     * @description Check CPU time limits
     */
    private static void checkCPUTime() {
        Integer threshold = getThresholdPercentage(LimitType.CPU_TIME);
        Integer used = Limits.getCpuTime();
        Integer max = Limits.getLimitCpuTime();
        Integer percentUsed = (used * 100) / max;
        
        if (percentUsed >= threshold) {
            logLimitWarning(LimitType.CPU_TIME, used, max, percentUsed);
        }
    }
    
    /**
     * @description Check heap size limits
     */
    private static void checkHeapSize() {
        Integer threshold = getThresholdPercentage(LimitType.HEAP_SIZE);
        Integer used = Limits.getHeapSize();
        Integer max = Limits.getLimitHeapSize();
        Integer percentUsed = (used * 100) / max;
        
        if (percentUsed >= threshold) {
            logLimitWarning(LimitType.HEAP_SIZE, used, max, percentUsed);
        }
    }
    
    /**
     * @description Log a warning when a limit threshold is exceeded
     * @param limitType The type of limit that was exceeded
     * @param used The amount of the limit used
     * @param max The maximum allowed
     * @param percentUsed The percentage of the limit used
     */
    private static void logLimitWarning(LimitType limitType, Integer used, Integer max, Integer percentUsed) {
        String message = String.format(
            'Governor limit warning: {0} is at {1}% ({2}/{3})', 
            new List<String>{
                limitType.name(), 
                String.valueOf(percentUsed), 
                String.valueOf(used), 
                String.valueOf(max)
            }
        );
        
        HIVES_Logger.warn(message, 'HIVES_LimitMonitor');
        
        // If critical threshold is reached, log as error
        Integer criticalThreshold = 90;
        if (percentUsed >= criticalThreshold) {
            HIVES_Logger.error('CRITICAL: ' + message, null, 'HIVES_LimitMonitor');
            // Consider sending platform event for critical warnings
        }
    }
    
    /**
     * @description Get a snapshot of current limit usage
     * @return Map<String, Object> Map of limit names to usage information
     */
    public static Map<String, Object> getLimitSnapshot() {
        Map<String, Object> snapshot = new Map<String, Object>();
        
        // SOQL limits
        snapshot.put('SOQL_QUERIES', new Map<String, Integer>{
            'used' => Limits.getQueries(),
            'max' => Limits.getLimitQueries()
        });
        
        // SOQL row limits
        snapshot.put('SOQL_ROWS', new Map<String, Integer>{
            'used' => Limits.getQueryRows(),
            'max' => Limits.getLimitQueryRows()
        });
        
        // DML limits
        snapshot.put('DML_OPERATIONS', new Map<String, Integer>{
            'used' => Limits.getDmlStatements(),
            'max' => Limits.getLimitDmlStatements()
        });
        
        snapshot.put('DML_ROWS', new Map<String, Integer>{
            'used' => Limits.getDmlRows(),
            'max' => Limits.getLimitDmlRows()
        });
        
        // CPU limits
        snapshot.put('CPU_TIME', new Map<String, Integer>{
            'used' => Limits.getCpuTime(),
            'max' => Limits.getLimitCpuTime()
        });
        
        // Heap limits
        snapshot.put('HEAP_SIZE', new Map<String, Integer>{
            'used' => Limits.getHeapSize(),
            'max' => Limits.getLimitHeapSize()
        });
        
        return snapshot;
    }
}
