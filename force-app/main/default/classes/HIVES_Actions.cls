/**
 * Plumbing for invocable actions called by Flow and Agentforce agents.
 *
 * An agent can't read a stack trace, and one bad input shouldn't fail the others. runEach runs a
 * step for each input, isolates failures, logs them (with the request id, so support can find the
 * debug log) and returns a readable error instead of throwing:
 *
 *   List<HIVES_Actions.Outcome> outcomes = HIVES_Actions.runEach('MyAction', inputs, new MyStep());
 *
 * Each input runs under its own savepoint, so a failed input's writes are rolled back. Savepoints
 * use DML statements, so inputs beyond the first MAX_ISOLATED are not rolled back individually; they
 * still fail independently. Agents call actions with one input, so this only matters for bulk flows.
 *
 * Write action queries and DML in user mode (WITH USER_MODE, AccessLevel.USER_MODE) so an agent
 * only sees and changes what the person it acts for may. See HIVES_AccountSnapshotAction.
 */
public inherited sharing class HIVES_Actions {

    @TestVisible static final Integer MAX_ISOLATED = 50;

    /** The work for one input. Return the output value; throw to report a failure. */
    public interface Step {
        Object run(Object input);
    }

    public class Outcome {
        public Boolean success = false;
        public Object value;
        public String errorMessage;
    }

    public static List<Outcome> runEach(String source, List<Object> inputs, Step step) {
        List<Outcome> outcomes = new List<Outcome>();
        for (Integer i = 0; i < inputs.size(); i++) {
            Outcome outcome = new Outcome();
            Savepoint sp = i < MAX_ISOLATED ? Database.setSavepoint() : null;
            try {
                outcome.value = step.run(inputs[i]);
                outcome.success = true;
            } catch (Exception e) {
                if (sp != null) {
                    Database.rollback(sp);
                }
                HIVES_Log.error(source, 'Input ' + (i + 1) + ' of ' + inputs.size() + ' failed', e);
                outcome.errorMessage = readable(e) + ' (request ' + Request.getCurrent().getRequestId() + ')';
            }
            outcomes.add(outcome);
        }
        return outcomes;
    }

    /** Validation and custom exception messages are meant for people; system exception text is not. */
    private static String readable(Exception e) {
        if (e instanceof DmlException) {
            return ((DmlException) e).getDmlMessage(0);
        }
        return e.getTypeName().startsWith('System.') ? 'The action could not be completed.' : e.getMessage();
    }
}
