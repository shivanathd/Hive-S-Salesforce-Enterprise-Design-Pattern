@isTest
private class AccountDefaultsHandlerTest {

    @isTest
    static void ratingDefaultsWithoutAnyDml() {
        // Handlers can be tested directly, without configuration or DML.
        List<Account> accounts = new List<Account>{ new Account(Name = 'No rating'), new Account(Name = 'Rated', Rating = 'Warm') };
        new AccountDefaultsHandler().handle(
            new HIVES_TriggerContext(System.TriggerOperation.BEFORE_INSERT, accounts, null), System.AccessLevel.SYSTEM_MODE);
        Assert.areEqual('Cold', accounts[0].Rating);
        Assert.areEqual('Warm', accounts[1].Rating);
    }

    @isTest
    static void hotAccountsGetAFollowUpTaskThroughTheTrigger() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{
            HIVES_TestData.handler('AccountDefaultsHandler', 'Account', 10)
        });
        Account hot = new Account(Name = 'Hot lead co', Rating = 'Hot');
        Account plain = new Account(Name = 'Plain co');

        insert new List<Account>{ hot, plain };

        Assert.areEqual('Cold', [SELECT Rating FROM Account WHERE Id = :plain.Id].Rating);
        Task t = [SELECT WhatId, OwnerId, Subject, Priority FROM Task];
        Assert.areEqual(hot.Id, t.WhatId);
        Assert.areEqual(UserInfo.getUserId(), t.OwnerId);
        Assert.areEqual('High', t.Priority);
    }
}
