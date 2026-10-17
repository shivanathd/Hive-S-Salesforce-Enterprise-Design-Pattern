/**
 * Example agent action: a short summary of an account for an Agentforce agent or a flow.
 * Queries run in user mode, so the agent only sees what the person it acts for may see.
 *
 * In Agentforce Builder: New Agent Action > Reference Action Type: Apex > Get Account Snapshot.
 */
public with sharing class HIVES_AccountSnapshotAction {

    public class Input {
        @InvocableVariable(label='Account ID' required=true)
        public Id accountId;
    }

    public class Output {
        @InvocableVariable(label='Found' description='False when the account does not exist or the user cannot see it.')
        public Boolean success;
        @InvocableVariable(label='Error')
        public String errorMessage;
        @InvocableVariable(label='Account Name')
        public String name;
        @InvocableVariable(label='Industry')
        public String industry;
        @InvocableVariable(label='Open Opportunities')
        public Integer openOpportunities;
        @InvocableVariable(label='Open Opportunity Amount')
        public Decimal openPipeline;
        @InvocableVariable(label='Open Cases')
        public Integer openCases;
    }

    @InvocableMethod(
        label='Get Account Snapshot'
        description='Returns an account\'s name, industry, open opportunity count and amount, and open case count, as the running user can see them.'
        category='HIVE-S'
    )
    public static List<Output> snapshot(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (HIVES_Actions.Outcome o : HIVES_Actions.runEach('HIVES_AccountSnapshotAction', inputs, new Snapshot())) {
            Output out = o.success ? (Output) o.value : new Output();
            out.success = o.success;
            out.errorMessage = o.errorMessage;
            results.add(out);
        }
        return results;
    }

    private with sharing class Snapshot implements HIVES_Actions.Step {
        public Object run(Object input) {
            Id accountId = ((Input) input).accountId;
            List<Account> found = [SELECT Name, Industry FROM Account WHERE Id = :accountId WITH USER_MODE];
            if (found.isEmpty()) {
                throw new NotFoundException('No account with that ID is visible to you.');
            }
            AggregateResult opps = [
                SELECT COUNT(Id) total, SUM(Amount) amount FROM Opportunity
                WHERE AccountId = :accountId AND IsClosed = false WITH USER_MODE
            ];
            Output out = new Output();
            out.name = found[0].Name;
            out.industry = found[0].Industry;
            out.openOpportunities = (Integer) opps.get('total');
            out.openPipeline = ((Decimal) opps.get('amount')) ?? 0;
            out.openCases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId AND IsClosed = false WITH USER_MODE];
            return out;
        }
    }

    public class NotFoundException extends Exception {}
}
