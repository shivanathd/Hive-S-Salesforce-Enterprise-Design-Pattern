@isTest
private class HIVES_ConfigTest {

    @isTest
    static void environmentSpecificValueWinsOverGeneralOne() {
        HIVES_Config.propertyOverride = new List<HIVES_SystemProperty__mdt>{
            HIVES_TestData.property('Orders.BatchSize', '200', null),
            HIVES_TestData.property('Orders.BatchSize', '20', 'SANDBOX'),
            HIVES_TestData.property('Orders.Blank', '', 'PRODUCTION')
        };

        HIVES_Config.environmentOverride = HIVES_Config.Environment.SANDBOX;
        Assert.areEqual(20, HIVES_Config.getInteger('Orders.BatchSize', 1));

        HIVES_Config.environmentOverride = HIVES_Config.Environment.PRODUCTION;
        Assert.areEqual(200, HIVES_Config.getInteger('Orders.BatchSize', 1));
        Assert.areEqual('fallback', HIVES_Config.getString('Orders.Blank', 'fallback'), 'Blank values use the default');
        Assert.areEqual('fallback', HIVES_Config.getString('Missing', 'fallback'));
    }

    @isTest
    static void typedGettersParseAndRejectBadValues() {
        HIVES_Config.propertyOverride = new List<HIVES_SystemProperty__mdt>{
            HIVES_TestData.property('Flag', 'TRUE', null),
            HIVES_TestData.property('Rate', '0.25', null),
            HIVES_TestData.property('Broken', 'ten', null)
        };
        Assert.isTrue(HIVES_Config.getBoolean('Flag', false));
        Assert.isFalse(HIVES_Config.getBoolean('Missing', false));
        Assert.areEqual(0.25, HIVES_Config.getDecimal('Rate', 0));
        Assert.areEqual(7, HIVES_Config.getDecimal('Missing', 7));
        try {
            HIVES_Config.getInteger('Broken', 0);
            Assert.fail('Expected a ConfigException');
        } catch (HIVES_Config.ConfigException e) {
            Assert.isTrue(e.getMessage().contains('Broken is not a whole number: ten'));
        }
        try {
            HIVES_Config.getDecimal('Broken', 0);
            Assert.fail('Expected a ConfigException');
        } catch (HIVES_Config.ConfigException e) {
            Assert.isTrue(e.getMessage().contains('Broken is not a number'));
        }
    }

    @isTest
    static void environmentIsDetectedFromTheOrg() {
        Assert.isNotNull(HIVES_Config.environment());
        Assert.areEqual(HIVES_Config.environment(), HIVES_Config.environment(), 'Stable within a transaction');
    }

    @isTest
    static void featureFlagsRespectActiveDatesAndPermission() {
        Datetime now = System.now();
        HIVES_Config.flagOverride = new List<HIVES_FeatureFlag__mdt>{
            HIVES_TestData.flag('On', true, null, null, null),
            HIVES_TestData.flag('Off', false, null, null, null),
            HIVES_TestData.flag('NotYet', true, now.addDays(1), null, null),
            HIVES_TestData.flag('Over', true, null, now.addDays(-1), null),
            HIVES_TestData.flag('Pilot', true, null, null, 'HIVES_Bypass_All_Triggers')
        };
        Assert.isTrue(HIVES_Config.isEnabled('On'));
        Assert.isFalse(HIVES_Config.isEnabled('Off'));
        Assert.isFalse(HIVES_Config.isEnabled('NotYet'));
        Assert.isFalse(HIVES_Config.isEnabled('Over'));
        Assert.isFalse(HIVES_Config.isEnabled('Unknown'));

        Boolean pilotForRep;
        Boolean pilotForPilotUser;
        System.runAs(HIVES_TestData.user('Standard User', null)) {
            pilotForRep = HIVES_Config.isEnabled('Pilot');
        }
        System.runAs(HIVES_TestData.user('Standard User', 'HIVES_Data_Load_Bypass')) {
            pilotForPilotUser = HIVES_Config.isEnabled('Pilot');
        }
        Assert.isFalse(pilotForRep, 'Users without the permission do not get the feature');
        Assert.isTrue(pilotForPilotUser, 'Users holding the permission do');
    }
}
