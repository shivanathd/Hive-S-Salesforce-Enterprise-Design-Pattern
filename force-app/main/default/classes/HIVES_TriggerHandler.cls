/**
 * Base class for trigger handlers. Override only the events you need; the others do nothing.
 *
 *   public with sharing class AccountDefaultsHandler extends HIVES_TriggerHandler {
 *       public override void beforeInsert(List<SObject> newRecords) {
 *           for (Account a : (List<Account>) newRecords) {
 *               a.Rating = a.Rating ?? 'Cold';
 *           }
 *       }
 *   }
 *
 * Then add a HIVES Trigger Handler record (Object = Account, Handler Class = AccountDefaultsHandler).
 *
 * Triggers always run in system mode. this.access carries the handler's configured Access Mode:
 * pass it to queries and DML (Database.query(soql, access), Database.insert(rows, access)) so that a
 * handler configured as User respects the saving user's sharing and permissions.
 */
public abstract inherited sharing class HIVES_TriggerHandler {

    protected HIVES_TriggerContext context;
    protected System.AccessLevel access = System.AccessLevel.SYSTEM_MODE;

    public virtual void beforeInsert(List<SObject> newRecords) {}
    public virtual void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public virtual void beforeDelete(Map<Id, SObject> oldMap) {}
    public virtual void afterInsert(List<SObject> newRecords) {}
    public virtual void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {}
    public virtual void afterDelete(Map<Id, SObject> oldMap) {}
    public virtual void afterUndelete(List<SObject> newRecords) {}

    /** Calls the method for the context's event. Used by HIVES_Trigger, and by tests to run a handler directly. */
    public void handle(HIVES_TriggerContext context, System.AccessLevel access) {
        this.context = context;
        this.access = access;
        switch on context.operation {
            when BEFORE_INSERT { beforeInsert(context.newRecords); }
            when BEFORE_UPDATE { beforeUpdate(context.newRecords, context.oldMap); }
            when BEFORE_DELETE { beforeDelete(context.oldMap); }
            when AFTER_INSERT { afterInsert(context.newRecords); }
            when AFTER_UPDATE { afterUpdate(context.newRecords, context.oldMap); }
            when AFTER_DELETE { afterDelete(context.oldMap); }
            when AFTER_UNDELETE { afterUndelete(context.newRecords); }
        }
    }
}
