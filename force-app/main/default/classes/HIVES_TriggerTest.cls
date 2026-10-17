@isTest
private class HIVES_TriggerTest {

    static List<String> calls = new List<String>();

    public class Recorder extends HIVES_TriggerHandler {
        public override void beforeInsert(List<SObject> r) { record(); }
        public override void beforeUpdate(List<SObject> r, Map<Id, SObject> o) { record(); }
        public override void beforeDelete(Map<Id, SObject> o) { record(); }
        public override void afterInsert(List<SObject> r) { record(); }
        public override void afterUpdate(List<SObject> r, Map<Id, SObject> o) { record(); }
        public override void afterDelete(Map<Id, SObject> o) { record(); }
        public override void afterUndelete(List<SObject> r) { record(); }
        void record() { calls.add('Recorder:' + context.operation + ':' + (access == System.AccessLevel.USER_MODE ? 'USER_MODE' : 'SYSTEM_MODE')); }
    }

    public class Second extends HIVES_TriggerHandler {
        public override void beforeInsert(List<SObject> r) { calls.add('Second:' + context.operation); }
    }

    public class Thrower extends HIVES_TriggerHandler {
        public override void beforeInsert(List<SObject> r) { throw new IllegalArgumentException('handler blew up'); }
    }

    public class SelfUpdater extends HIVES_TriggerHandler {
        public override void afterUpdate(List<SObject> records, Map<Id, SObject> oldMap) {
            calls.add('SelfUpdater');
            List<Account> again = new List<Account>();
            for (Account a : (List<Account>) records) {
                if (a.Description != 'nested') {
                    again.add(new Account(Id = a.Id, Description = 'nested'));
                }
            }
            update again;
        }
    }

    public class DescriptionSetter extends HIVES_TriggerHandler {
        public override void beforeInsert(List<SObject> records) {
            for (Account a : (List<Account>) records) {
                a.Description = 'set by handler';
            }
        }
    }

    public class NotAHandler {}

    static HIVES_TriggerConfiguration__mdt config(String innerClass, Integer order) {
        return HIVES_TestData.handler('HIVES_TriggerTest.' + innerClass, 'Account', order);
    }

    @isTest
    static void everyEventReachesTheHandlerIncludingDeleteAndUndelete() {
        // v1 threw a NullPointerException on every delete, so no Account could be deleted.
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('Recorder', 1) });
        Account a = new Account(Name = 'Lifecycle');

        Test.startTest();
        insert a;
        update a;
        delete a;
        undelete a;
        Test.stopTest();

        Assert.areEqual(new List<String>{
            'Recorder:BEFORE_INSERT:SYSTEM_MODE', 'Recorder:AFTER_INSERT:SYSTEM_MODE',
            'Recorder:BEFORE_UPDATE:SYSTEM_MODE', 'Recorder:AFTER_UPDATE:SYSTEM_MODE',
            'Recorder:BEFORE_DELETE:SYSTEM_MODE', 'Recorder:AFTER_DELETE:SYSTEM_MODE',
            'Recorder:AFTER_UNDELETE:SYSTEM_MODE'
        }, calls);
    }

    @isTest
    static void handlersRunInExecutionOrderAndOnlyForTheirObject() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{
            config('Second', 20),
            config('Recorder', 10),
            (HIVES_TriggerConfiguration__mdt) HIVES_TestData.with(config('Thrower', 5), 'Object__c', 'Contact'),
            (HIVES_TriggerConfiguration__mdt) HIVES_TestData.with(config('Thrower', 6), 'IsActive__c', false)
        });

        insert new Account(Name = 'Ordered');

        Assert.areEqual('Recorder:BEFORE_INSERT:SYSTEM_MODE', calls[0]);
        Assert.areEqual('Second:BEFORE_INSERT', calls[1]);
    }

    @isTest
    static void userAccessModeIsPassedToTheHandler() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{
            (HIVES_TriggerConfiguration__mdt) HIVES_TestData.with(config('Recorder', 1), 'AccessMode__c', 'User')
        });
        insert new Account(Name = 'User mode');
        Assert.areEqual('Recorder:BEFORE_INSERT:USER_MODE', calls[0]);
    }

    @isTest
    static void bypassInCodeSkipsAHandlerUntilCleared() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('Recorder', 1), config('Second', 2) });

        HIVES_Trigger.bypass(Recorder.class);
        insert new Account(Name = 'Bypassed');
        Assert.areEqual(new List<String>{ 'Second:BEFORE_INSERT' }, calls);

        calls.clear();
        HIVES_Trigger.clearBypass(Recorder.class);
        insert new Account(Name = 'Not bypassed');
        Assert.areEqual(3, calls.size(), String.valueOf(calls));

        calls.clear();
        HIVES_Trigger.bypass(Recorder.class);
        HIVES_Trigger.clearAllBypasses();
        insert new Account(Name = 'Cleared');
        Assert.areEqual(3, calls.size());
    }

    @isTest
    static void dataLoadBypassPermissionSkipsEveryHandler() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('Recorder', 1) });
        User loader = HIVES_TestData.user('Standard User', 'HIVES_Data_Load_Bypass');

        System.runAs(loader) {
            insert new Account(Name = 'Loaded');
        }

        Assert.areEqual(0, calls.size(), String.valueOf(calls));
        Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Name = 'Loaded'], 'The record still saves');
    }

    @isTest
    static void handlerBypassPermissionOnlyAppliesToUsersHoldingIt() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{
            (HIVES_TriggerConfiguration__mdt) HIVES_TestData.with(config('Recorder', 1), 'BypassPermission__c', 'HIVES_Bypass_All_Triggers')
        });
        User rep = HIVES_TestData.user('Standard User', null);
        System.runAs(rep) {
            insert new Account(Name = 'Rep save');
        }
        Assert.areEqual(2, calls.size(), 'A user without the permission still runs the handler');
    }

    @isTest
    static void aHandlerDoesNotReEnterItselfUnlessAllowed() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('SelfUpdater', 1) });
        Account a = new Account(Name = 'Recursion');
        insert a;

        update new Account(Id = a.Id, Description = 'first');

        Assert.areEqual(1, calls.size(), 'The nested update from the handler is not re-handled');
        Assert.areEqual('nested', [SELECT Description FROM Account WHERE Id = :a.Id].Description);
    }

    @isTest
    static void aHandlerReEntersWhenRecursionIsAllowed() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{
            (HIVES_TriggerConfiguration__mdt) HIVES_TestData.with(config('SelfUpdater', 1), 'AllowRecursion__c', true)
        });
        Account a = new Account(Name = 'Recursion allowed');
        insert a;

        update new Account(Id = a.Id, Description = 'first');

        Assert.areEqual(2, calls.size(), 'Outer update plus the nested one');
    }

    @isTest
    static void partialSuccessSavesStillRunTheHandlers() {
        // With allOrNone=false Salesforce re-runs the trigger for the records that can succeed. v1's
        // static "already processed" guard skipped that second run, saving records without their logic.
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('DescriptionSetter', 1) });
        Account good = new Account(Name = 'Good');
        Account bad = new Account();

        List<Database.SaveResult> results = Database.insert(new List<Account>{ good, bad }, false);

        Assert.isTrue(results[0].isSuccess());
        Assert.isFalse(results[1].isSuccess());
        Assert.areEqual('set by handler', [SELECT Description FROM Account WHERE Id = :good.Id].Description);
    }

    @isTest
    static void aFailingHandlerFailsTheSaveAndLeavesALogThatSurvivesTheRollback() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('Thrower', 1) });
        String error;

        Test.startTest();
        try {
            insert new Account(Name = 'Boom');
        } catch (DmlException e) {
            error = e.getMessage();
        }
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.isTrue(error.contains('handler blew up'), error);
        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Name = 'Boom']);
        HIVES_Log__c log = [SELECT Level__c, Source__c, Message__c, StackTrace__c FROM HIVES_Log__c WITH SYSTEM_MODE];
        Assert.areEqual('ERROR', log.Level__c);
        Assert.areEqual('HIVES_TriggerTest.Thrower', log.Source__c);
        Assert.isTrue(log.Message__c.contains('Account BEFORE_INSERT failed'), log.Message__c);
        Assert.isNotNull(log.StackTrace__c);
    }

    @isTest
    static void misconfiguredHandlersFailWithTheRecordName() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ HIVES_TestData.handler('NoSuchClass', 'Account', 1) });
        try {
            insert new Account(Name = 'Missing class');
            Assert.fail('Expected a configuration error');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('HIVES Trigger Handler "NoSuchClass": class NoSuchClass does not exist'), e.getMessage());
        }

        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{ config('NotAHandler', 1) });
        try {
            insert new Account(Name = 'Wrong type');
            Assert.fail('Expected a configuration error');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('does not extend HIVES_TriggerHandler'), e.getMessage());
        }
    }

    @isTest
    static void configurationProblemsListsEveryBrokenRecord() {
        HIVES_TestData.useHandlers(new List<HIVES_TriggerConfiguration__mdt>{
            config('Recorder', 1),
            HIVES_TestData.handler('NoSuchClass', 'Account', 2),
            (HIVES_TriggerConfiguration__mdt) HIVES_TestData.with(config('Second', 3), 'Object__c', 'NoSuchObject__c')
        });

        List<String> problems = HIVES_Trigger.configurationProblems();

        Assert.areEqual(2, problems.size(), String.valueOf(problems));
        Assert.isTrue(problems[0].contains('NoSuchClass does not exist'), problems[0]);
        Assert.isTrue(problems[1].contains('unknown object NoSuchObject__c'), problems[1]);
    }

    @isTest
    static void aContextNeedsRecords() {
        try {
            new HIVES_TriggerContext(System.TriggerOperation.BEFORE_INSERT, new List<Account>(), null);
            Assert.fail('Expected an error');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('at least one record'));
        }
    }
}
