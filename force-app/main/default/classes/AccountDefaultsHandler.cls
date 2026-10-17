/**
 * Sample handler (shipped inactive). Defaults a new account's Rating, and creates a follow-up task
 * for the owner of each new Hot account, using the handler's configured access mode for the insert.
 *
 * Activate it with the "Account Defaults" HIVES Trigger Handler record.
 *
 * The CRUD warning is suppressed because the access mode is the configured one (this.access), which
 * static analysis can't see.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class AccountDefaultsHandler extends HIVES_TriggerHandler {

    public override void beforeInsert(List<SObject> newRecords) {
        for (Account a : (List<Account>) newRecords) {
            a.Rating = a.Rating ?? 'Cold';
        }
    }

    public override void afterInsert(List<SObject> newRecords) {
        List<Task> followUps = new List<Task>();
        for (Account a : (List<Account>) newRecords) {
            if (a.Rating == 'Hot') {
                followUps.add(new Task(
                    WhatId = a.Id, OwnerId = a.OwnerId, Subject = ('Call new hot account: ' + a.Name).left(255),
                    ActivityDate = Date.today().addDays(1), Priority = 'High'
                ));
            }
        }
        if (!followUps.isEmpty()) {
            Database.insert(followUps, access);
        }
    }
}
