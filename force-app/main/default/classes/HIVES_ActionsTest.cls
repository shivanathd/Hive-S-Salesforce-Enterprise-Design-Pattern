@isTest
private class HIVES_ActionsTest {

    static HIVES_AccountSnapshotAction.Input input(Id accountId) {
        HIVES_AccountSnapshotAction.Input i = new HIVES_AccountSnapshotAction.Input();
        i.accountId = accountId;
        return i;
    }

    public class InsertThenFail implements HIVES_Actions.Step {
        public Object run(Object input) {
            insert new Account(Name = (String) input);
            if (input == 'fail') {
                throw new IllegalArgumentException('second step failed');
            }
            return 'ok';
        }
    }

    @isTest
    static void snapshotSummarisesTheAccount() {
        Account a = new Account(Name = 'Acme', Industry = 'Energy');
        insert a;
        insert new List<Opportunity>{
            new Opportunity(AccountId = a.Id, Name = 'Open 1', StageName = 'Prospecting', CloseDate = Date.today(), Amount = 1000),
            new Opportunity(AccountId = a.Id, Name = 'Open 2', StageName = 'Prospecting', CloseDate = Date.today(), Amount = 500),
            new Opportunity(AccountId = a.Id, Name = 'Won', StageName = 'Closed Won', CloseDate = Date.today(), Amount = 9999)
        };
        insert new Case(AccountId = a.Id, Subject = 'Help', Status = 'New');

        List<HIVES_AccountSnapshotAction.Output> out = HIVES_AccountSnapshotAction.snapshot(
            new List<HIVES_AccountSnapshotAction.Input>{ input(a.Id) });

        Assert.isTrue(out[0].success);
        Assert.areEqual('Acme', out[0].name);
        Assert.areEqual('Energy', out[0].industry);
        Assert.areEqual(2, out[0].openOpportunities);
        Assert.areEqual(1500, out[0].openPipeline);
        Assert.areEqual(1, out[0].openCases);
    }

    @isTest
    static void missingAccountGivesAReadableErrorNotAnException() {
        Account a = new Account(Name = 'Gone');
        insert a;
        delete a;

        List<HIVES_AccountSnapshotAction.Output> out = HIVES_AccountSnapshotAction.snapshot(
            new List<HIVES_AccountSnapshotAction.Input>{ input(a.Id) });

        Assert.isFalse(out[0].success);
        Assert.isTrue(out[0].errorMessage.startsWith('No account with that ID is visible to you. (request '), out[0].errorMessage);
    }

    @isTest
    static void userModeMeansTheAgentSeesOnlyWhatTheUserMay() {
        Account a = new Account(Name = 'Private');
        insert a;
        User noAccess = HIVES_TestData.user('Minimum Access - Salesforce', null);
        List<HIVES_AccountSnapshotAction.Output> out;
        System.runAs(noAccess) {
            out = HIVES_AccountSnapshotAction.snapshot(new List<HIVES_AccountSnapshotAction.Input>{ input(a.Id) });
        }
        Assert.isFalse(out[0].success, 'A user with no Account access gets nothing');
        Assert.isNull(out[0].name);
    }

    @isTest
    static void aFailedInputIsRolledBackWithoutAffectingTheOthers() {
        Test.startTest();
        List<HIVES_Actions.Outcome> outcomes = HIVES_Actions.runEach('Test', new List<Object>{ 'first', 'fail', 'third' }, new InsertThenFail());
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.isTrue(outcomes[0].success);
        Assert.isFalse(outcomes[1].success);
        Assert.isTrue(outcomes[1].errorMessage.startsWith('The action could not be completed. (request '), 'System exception text is not shown');
        Assert.isTrue(outcomes[2].success);
        Assert.areEqual(new Set<String>{ 'first', 'third' }, names([SELECT Name FROM Account]), 'The failed input\'s insert was rolled back');
        Assert.areEqual(1, [SELECT COUNT() FROM HIVES_Log__c WHERE Source__c = 'Test' WITH SYSTEM_MODE], 'The failure is logged');
    }

    @isTest
    static void inputsBeyondTheIsolationLimitStillFailIndependently() {
        List<Object> inputs = new List<Object>();
        for (Integer i = 0; i <= HIVES_Actions.MAX_ISOLATED; i++) {
            inputs.add('a' + i);
        }
        inputs.add('fail');
        List<HIVES_Actions.Outcome> outcomes = HIVES_Actions.runEach('Test', inputs, new InsertThenFail());
        Assert.isFalse(outcomes[outcomes.size() - 1].success);
        Assert.isTrue(outcomes[0].success);
    }

    static Set<String> names(List<Account> accounts) {
        Set<String> result = new Set<String>();
        for (Account a : accounts) {
            result.add(a.Name);
        }
        return result;
    }
}
