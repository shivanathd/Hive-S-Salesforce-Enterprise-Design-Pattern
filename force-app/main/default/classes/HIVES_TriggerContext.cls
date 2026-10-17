/**
 * What a handler sees: the event and records of the current trigger.
 * Build one directly in tests to run a handler without DML.
 */
public inherited sharing class HIVES_TriggerContext {

    public final System.TriggerOperation operation;
    public final SObjectType sObjectType;
    /** Trigger.new: null on delete. */
    public final List<SObject> newRecords;
    /** Trigger.oldMap: null on insert and undelete. */
    public final Map<Id, SObject> oldMap;

    public HIVES_TriggerContext(System.TriggerOperation operation, List<SObject> newRecords, Map<Id, SObject> oldMap) {
        List<SObject> records = newRecords ?? (oldMap == null ? null : oldMap.values());
        if (operation == null || records == null || records.isEmpty()) {
            throw new IllegalArgumentException('A trigger context needs an operation and at least one record.');
        }
        this.operation = operation;
        this.newRecords = newRecords;
        this.oldMap = oldMap;
        this.sObjectType = records[0].getSObjectType();
    }
}
