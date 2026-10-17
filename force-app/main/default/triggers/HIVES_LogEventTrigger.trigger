/** Saves HIVE-S log events as HIVES_Log__c records. */
trigger HIVES_LogEventTrigger on HIVES_LogEvent__e (after insert) {
    HIVES_Log.save(Trigger.new);
}
