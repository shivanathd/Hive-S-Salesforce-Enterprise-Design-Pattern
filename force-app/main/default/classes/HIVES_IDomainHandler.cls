/**
 * @description Interface for domain handlers to implement
 * Provides the contract for trigger handler classes in the HIVE-S Framework
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public interface HIVES_IDomainHandler {
    /**
     * @description Set the context for this handler
     * @param newRecords The list of new records
     * @param oldMap The map of old records
     * @param operation The trigger operation
     * @param context The transaction context
     */
    void setContext(SObject[] newRecords, Map<Id, SObject> oldMap, 
                    System.TriggerOperation operation, HIVES_TransactionContext context);
    
    /**
     * @description Execute this handler's business logic
     */
    void execute();
}
