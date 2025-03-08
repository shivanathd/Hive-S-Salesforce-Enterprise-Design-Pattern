/**
 * @description Domain handler for Account in the HIVE-S Framework
 * Implements business logic for Account entity.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public class AccountDomainHandler implements HIVES_IDomainHandler {
    private Account[] newRecords;
    private Map<Id, Account> oldMap;
    private System.TriggerOperation operation;
    private HIVES_TransactionContext context;
    
    /**
     * @description Set the context for this handler
     * @param newRecords The list of new records
     * @param oldMap The map of old records
     * @param operation The trigger operation
     * @param context The transaction context
     */
    public void setContext(SObject[] newRecords, Map<Id, SObject> oldMap, 
                           System.TriggerOperation operation, HIVES_TransactionContext context) {
        this.newRecords = (Account[])newRecords;
        this.oldMap = (Map<Id, Account>)oldMap;
        this.operation = operation;
        this.context = context;
    }
    
    /**
     * @description Execute this handler's business logic
     */
    public void execute() {
        switch on operation {
            when BEFORE_INSERT {
                handleBeforeInsert();
            }
            when BEFORE_UPDATE {
                handleBeforeUpdate();
            }
            when AFTER_UPDATE {
                handleAfterUpdate();
            }
            when AFTER_INSERT {
                handleAfterInsert();
            }
            // Additional contexts would be implemented here
        }
    }
    
    /**
     * @description Handle before insert logic
     */
    private void handleBeforeInsert() {
        Set<String> nameSet = new Set<String>();
        
        // Collect all names for duplicate check
        for (Account acc : newRecords) {
            if (String.isNotBlank(acc.Name)) {
                nameSet.add(acc.Name.toLowerCase());
            }
        }
        
        // If we have names to check, query for existing
        if (!nameSet.isEmpty()) {
            // Query for existing accounts with same names
            List<Account> existingAccounts = [
                SELECT Id, Name 
                FROM Account 
                WHERE Name IN :nameSet
            ];
            
            Map<String, Account> existingAccountsByName = new Map<String, Account>();
            for (Account acc : existingAccounts) {
                existingAccountsByName.put(acc.Name.toLowerCase(), acc);
            }
            
            // Now check each record for duplicates
            for (Account acc : newRecords) {
                if (String.isNotBlank(acc.Name) && 
                    existingAccountsByName.containsKey(acc.Name.toLowerCase())) {
                    acc.addError('An account with this name already exists.');
                }
            }
        }
        
        // Apply default values for missing fields
        for (Account acc : newRecords) {
            if (acc.Rating == null) {
                acc.Rating = 'Cold';
            }
            
            // Set default industry if none specified
            if (String.isBlank(acc.Industry)) {
                acc.Industry = 'Other';
            }
        }
    }
    
    /**
     * @description Handle before update logic
     */
    private void handleBeforeUpdate() {
        for (Account acc : newRecords) {
            Account oldAcc = oldMap.get(acc.Id);
            
            // Implement business validation logic
            
            // Example: Prevent changing account name if it has opportunities
            if (acc.Name != oldAcc.Name && context.containsKey('HasOpportunities:' + acc.Id)) {
                Boolean hasOpps = (Boolean)context.get('HasOpportunities:' + acc.Id);
                if (hasOpps) {
                    acc.Name.addError('Cannot change account name when it has associated opportunities.');
                }
            }
            
            // Example: Automatically update account rating based on annual revenue changes
            if (acc.AnnualRevenue != oldAcc.AnnualRevenue) {
                updateRatingBasedOnRevenue(acc);
            }
        }
    }
    
    /**
     * @description Handle after update logic
     */
    private void handleAfterUpdate() {
        Set<Id> accountsNeedingContactUpdate = new Set<Id>();
        
        for (Account acc : newRecords) {
            Account oldAcc = oldMap.get(acc.Id);
            
            // Example: If billing address changed, flag for contact address updates
            if (addressChanged(acc, oldAcc)) {
                accountsNeedingContactUpdate.add(acc.Id);
            }
        }
        
        // If we have accounts needing contact updates, store in context for cross-object processing
        if (!accountsNeedingContactUpdate.isEmpty()) {
            context.put('AccountsNeedingContactUpdate', accountsNeedingContactUpdate);
            
            // For actual implementation, you might queue a job to process these
            if (!System.isFuture() && !System.isQueueable() && Limits.getLimitQueueableJobs() > Limits.getQueueableJobs()) {
                // queueContactAddressUpdate(accountsNeedingContactUpdate);
            }
        }
    }
    
    /**
     * @description Handle after insert logic
     */
    private void handleAfterInsert() {
        // Example: Create default related records or perform post-insert processing
        
        // We could create default contacts, or assign to territories, etc.
        // This would call service layer methods rather than performing DML directly
    }
    
    /**
     * @description Check if any address fields have changed
     * @param newAcc The new account record
     * @param oldAcc The old account record
     * @return Boolean True if address changed
     */
    private Boolean addressChanged(Account newAcc, Account oldAcc) {
        return newAcc.BillingStreet != oldAcc.BillingStreet ||
               newAcc.BillingCity != oldAcc.BillingCity ||
               newAcc.BillingState != oldAcc.BillingState ||
               newAcc.BillingPostalCode != oldAcc.BillingPostalCode ||
               newAcc.BillingCountry != oldAcc.BillingCountry;
    }
    
    /**
     * @description Update account rating based on annual revenue
     * @param acc The account to update
     */
    private void updateRatingBasedOnRevenue(Account acc) {
        if (acc.AnnualRevenue == null) {
            acc.Rating = 'Cold';
        } else if (acc.AnnualRevenue > 1000000) {
            acc.Rating = 'Hot';
        } else if (acc.AnnualRevenue > 250000) {
            acc.Rating = 'Warm';
        } else {
            acc.Rating = 'Cold';
        }
    }
}
