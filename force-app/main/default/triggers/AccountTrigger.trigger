/**
 * @description Account trigger using the HIVE-S Framework
 * Implements the single trigger per object pattern.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
trigger AccountTrigger on Account (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    // Initialize the trigger handler with the current context
    HIVES_TriggerHandler handler = new HIVES_TriggerHandler(
        Trigger.new,
        Trigger.oldMap,
        Trigger.operationType
    );
    
    // Run the handler
    handler.run();
}
