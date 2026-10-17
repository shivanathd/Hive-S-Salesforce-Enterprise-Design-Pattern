/**
 * Fails the deploy when any HIVES Trigger Handler record is broken (missing class, class that doesn't
 * extend HIVES_TriggerHandler, unknown object), so the problem never reaches a user's save.
 * Runs against the org's real records.
 */
@isTest
private class HIVES_ConfigurationCheckTest {

    @isTest
    static void everyTriggerHandlerRecordIsValid() {
        List<String> problems = HIVES_Trigger.configurationProblems();
        Assert.areEqual(0, problems.size(), 'Fix these HIVES Trigger Handler records:\n' + String.join(problems, '\n'));
    }
}
