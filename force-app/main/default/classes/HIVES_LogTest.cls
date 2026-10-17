@isTest
private class HIVES_LogTest {

    static List<HIVES_Log__c> logs() {
        return [SELECT Level__c, Source__c, Message__c, StackTrace__c, RequestId__c, User__c FROM HIVES_Log__c WITH SYSTEM_MODE ORDER BY Name];
    }

    @isTest
    static void defaultLevelKeepsWarningsAndErrorsOnly() {
        Test.startTest();
        HIVES_Log.debug('Test', 'debug entry');
        HIVES_Log.info('Test', 'info entry');
        HIVES_Log.warn('Test', 'warn entry');
        HIVES_Log.error('Test', 'error entry');
        Test.getEventBus().deliver();
        Test.stopTest();

        List<HIVES_Log__c> saved = logs();
        Assert.areEqual(2, saved.size());
        Assert.areEqual('WARN', saved[0].Level__c);
        Assert.areEqual('ERROR', saved[1].Level__c);
        Assert.areEqual(UserInfo.getUserId(), saved[1].User__c);
        Assert.isNotNull(saved[1].RequestId__c);
    }

    @isTest
    static void exceptionsKeepTypeMessageAndStackTrace() {
        Test.startTest();
        try {
            Integer.valueOf('not a number');
        } catch (Exception e) {
            HIVES_Log.error('Parser', 'Could not parse', e);
        }
        Test.getEventBus().deliver();
        Test.stopTest();

        HIVES_Log__c log = logs()[0];
        Assert.areEqual('Parser', log.Source__c);
        Assert.isTrue(log.Message__c.startsWith('Could not parse\nSystem.TypeException'), log.Message__c);
        Assert.isNotNull(log.StackTrace__c);
    }

    @isTest
    static void levelIsConfigurable() {
        HIVES_Config.propertyOverride = new List<HIVES_SystemProperty__mdt>{ HIVES_TestData.property('HIVES.Log.Level', 'debug', null) };
        Test.startTest();
        HIVES_Log.debug('Test', 'now kept');
        Test.getEventBus().deliver();
        Test.stopTest();
        Assert.areEqual(1, logs().size());
    }

    @isTest
    static void unknownLevelFallsBackToWarn() {
        HIVES_Config.propertyOverride = new List<HIVES_SystemProperty__mdt>{ HIVES_TestData.property('HIVES.Log.Level', 'VERBOSE', null) };
        Test.startTest();
        HIVES_Log.info('Test', 'dropped');
        HIVES_Log.warn('Test', 'kept');
        Test.getEventBus().deliver();
        Test.stopTest();
        Assert.areEqual(1, logs().size());
    }
}
