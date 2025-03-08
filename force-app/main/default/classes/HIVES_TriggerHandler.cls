/**
 * @description Universal Trigger Handler for the HIVE-S Framework
 * Provides a standardized approach to handling triggers with built-in
 * bulkification, transaction management, and event delegation.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public virtual class HIVES_TriggerHandler {
    
    // Prevent recursive execution
    private static Set<String> processedIds = new Set<String>();
    
    // Transaction context to maintain state across trigger invocations
    @TestVisible
    private static HIVES_TransactionContext transactionContext;
    
    // SObject being processed
    private SObject[] newRecords;
    private Map<Id, SObject> oldMap;
    private System.TriggerOperation operation;
    private String objectType;
    
    /**
     * @description Constructor to initialize the handler with trigger context
     * @param newList The list of new records from trigger.new
     * @param oldMap The map of old records from trigger.oldMap
     * @param op The trigger operation (BEFORE_INSERT, AFTER_UPDATE, etc.)
     */
    public HIVES_TriggerHandler(SObject[] newList, Map<Id, SObject> oldMap, System.TriggerOperation op) {
        this.newRecords = newList;
        this.oldMap = oldMap;
        this.operation = op;
        this.objectType = newList != null && !newList.isEmpty() 
            ? String.valueOf(newList[0].getSObjectType()) 
            : String.valueOf(oldMap.values()[0].getSObjectType());
            
        // Initialize transaction context if not exists
        if (transactionContext == null) {
            transactionContext = new HIVES_TransactionContext();
        }
    }
    
    /**
     * @description Main entry point for trigger handling
     * @return void
     */
    public void run() {
        try {
            // Check if trigger processing is enabled for this object
            if (!isProcessingEnabled()) {
                return;
            }
            
            // Prevent recursive execution if configured
            if (isRecursiveExecution() && shouldPreventRecursion()) {
                return;
            }
            
            // Register processed IDs to prevent recursion if needed
            registerProcessedIds();
            
            // Monitor governor limits
            HIVES_LimitMonitor.checkLimits();
            
            // Get metadata-driven handler configurations
            List<HIVES_TriggerConfiguration__mdt> handlers = getHandlerConfigurations();
            
            // Execute each handler in the specified order
            for (HIVES_TriggerConfiguration__mdt handlerConfig : handlers) {
                if (handlerConfig.IsActive__c) {
                    executeHandler(handlerConfig);
                }
            }
            
            // Publish domain events if in after context
            if (operation == System.TriggerOperation.AFTER_INSERT || 
                operation == System.TriggerOperation.AFTER_UPDATE || 
                operation == System.TriggerOperation.AFTER_DELETE || 
                operation == System.TriggerOperation.AFTER_UNDELETE) {
                publishDomainEvents();
            }
            
            // Log transaction metrics
            logTransactionMetrics();
            
        } catch (Exception e) {
            // Log the exception
            HIVES_Logger.error('Trigger execution error', e, 'HIVES_TriggerHandler');
            
            // Handle the exception according to configuration
            handleException(e);
        }
    }
    
    /**
     * @description Check if trigger processing is enabled via custom metadata
     * @return Boolean Whether processing is enabled
     */
    private Boolean isProcessingEnabled() {
        HIVES_SystemProperty__mdt config = HIVES_ConfigurationService.getSystemProperty(
            'TriggerProcessing.' + objectType + '.Enabled');
        return config == null || config.BooleanValue__c;
    }
    
    /**
     * @description Get ordered list of handler configurations for current object and context
     * @return List<HIVES_TriggerConfiguration__mdt> Ordered handler configurations
     */
    private List<HIVES_TriggerConfiguration__mdt> getHandlerConfigurations() {
        String context = getContextName();
        return [
            SELECT Id, HandlerClass__c, ExecutionOrder__c
            FROM HIVES_TriggerConfiguration__mdt
            WHERE Object__c = :objectType
            AND Context__c = :context
            AND IsActive__c = true
            ORDER BY ExecutionOrder__c ASC
        ];
    }
    
    /**
     * @description Convert trigger operation to context name string
     * @return String Context name (BEFORE_INSERT, AFTER_UPDATE, etc.)
     */
    private String getContextName() {
        return operation.name();
    }
    
    /**
     * @description Execute a specific handler based on configuration
     * @param handlerConfig The handler configuration to execute
     */
    private void executeHandler(HIVES_TriggerConfiguration__mdt handlerConfig) {
        Type handlerType = Type.forName(handlerConfig.HandlerClass__c);
        if (handlerType != null) {
            HIVES_IDomainHandler handler = (HIVES_IDomainHandler)handlerType.newInstance();
            
            // Set context for the handler
            handler.setContext(newRecords, oldMap, operation, transactionContext);
            
            // Execute handler
            handler.execute();
        } else {
            HIVES_Logger.error(
                'Handler class not found: ' + handlerConfig.HandlerClass__c,
                null,
                'HIVES_TriggerHandler'
            );
        }
    }
    
    /**
     * @description Check if we're in a recursive execution
     * @return Boolean Whether this is a recursive execution
     */
    private Boolean isRecursiveExecution() {
        if (operation == System.TriggerOperation.BEFORE_INSERT || 
            operation == System.TriggerOperation.AFTER_INSERT) {
            return false; // Insert is never recursive
        }
        
        // Check if any IDs in the current context were already processed
        for (SObject record : newRecords) {
            String idKey = String.valueOf(record.Id) + getContextName();
            if (processedIds.contains(idKey)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @description Check if recursion prevention is configured for this object
     * @return Boolean Whether recursion should be prevented
     */
    private Boolean shouldPreventRecursion() {
        HIVES_SystemProperty__mdt config = HIVES_ConfigurationService.getSystemProperty(
            'TriggerProcessing.' + objectType + '.PreventRecursion');
        return config != null && config.BooleanValue__c;
    }
    
    /**
     * @description Register current record IDs as processed to prevent recursion
     */
    private void registerProcessedIds() {
        if (shouldPreventRecursion() && newRecords != null) {
            for (SObject record : newRecords) {
                if (record.Id != null) {
                    String idKey = String.valueOf(record.Id) + getContextName();
                    processedIds.add(idKey);
                }
            }
        }
    }
    
    /**
     * @description Publish domain events for after-trigger contexts
     */
    private void publishDomainEvents() {
        // Implementation would publish platform events
        // This is a placeholder for the actual implementation
        
        /* Example implementation:
        List<HIVES_DomainEvent__e> events = prepareDomainEvents();
        
        if (!events.isEmpty()) {
            try {
                List<Database.SaveResult> results = EventBus.publish(events);
                
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        HIVES_Logger.error(
                            'Failed to publish domain event: ' + events[i],
                            results[i].getErrors(),
                            'HIVES_TriggerHandler'
                        );
                    }
                }
            } catch (Exception e) {
                HIVES_Logger.error('Error publishing domain events', e, 'HIVES_TriggerHandler');
            }
        }
        */
    }
    
    /**
     * @description Log metrics about the current transaction
     */
    private void logTransactionMetrics() {
        // Implementation would log metrics to a custom object or platform event
        // This is a placeholder for the actual implementation
        
        /* Example implementation:
        if (HIVES_ConfigurationService.isFeatureEnabled('TransactionMonitoring')) {
            HIVES_TransactionMonitor__c metrics = new HIVES_TransactionMonitor__c(
                TransactionId__c = transactionContext.getTransactionId(),
                ObjectType__c = objectType,
                TriggerOperation__c = operation.name(),
                RecordCount__c = newRecords != null ? newRecords.size() : 0,
                SOQLQueries__c = Limits.getQueries(),
                DMLRows__c = Limits.getDmlRows(),
                CPUTime__c = Limits.getCpuTime(),
                HeapSize__c = Limits.getHeapSize()
            );
            
            try {
                insert metrics;
            } catch (Exception e) {
                HIVES_Logger.error('Failed to log transaction metrics', e, 'HIVES_TriggerHandler');
            }
        }
        */
    }
    
    /**
     * @description Handle exceptions based on configuration
     * @param e The exception that was caught
     */
    private void handleException(Exception e) {
        // Check if we should suppress exceptions (convert to logged errors)
        Boolean suppressExceptions = false;
        HIVES_SystemProperty__mdt config = HIVES_ConfigurationService.getSystemProperty(
            'TriggerProcessing.' + objectType + '.SuppressExceptions');
        
        if (config != null && config.BooleanValue__c) {
            suppressExceptions = true;
        }
        
        // If we're not suppressing, re-throw to fail the transaction
        if (!suppressExceptions) {
            throw e;
        }
    }
    
    /**
     * @description Reset the static context between test methods
     */
    @TestVisible
    private static void resetContext() {
        processedIds.clear();
        transactionContext = null;
    }
}
