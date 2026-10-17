# HIVE-S

A small Salesforce trigger and Agentforce-action framework for API 68 (Winter '27). It is about
550 lines of Apex (plus 600 lines of tests), and you can read all of it in an afternoon.

- **Trigger dispatcher.** Each object gets one line of trigger code. Handlers are switched on, ordered and bypassed through custom metadata, without a deploy.
- **Rollback-proof logger.** Errors are logged through a Publish Immediately platform event, so the log survives when the transaction that wrote it fails.
- **Agent action base.** Invocable actions for Agentforce and Flow run each input in isolation, return a readable error instead of throwing, and query in user mode.
- **Config and feature flags.** Settings and flags come from custom metadata, with per-environment values and permission-gated flags. Reading them costs no SOQL.
- **Configuration check.** A test fails the deploy when a handler record names a missing class or object, so a bad record doesn't break saves later.

## Should you use it?

| You want | Use |
|---|---|
| A full enterprise layering (selectors, unit of work, domains) | [fflib Apex Common](https://github.com/apex-enterprise-patterns/fflib-apex-common) |
| Admin-configurable triggers mixing Flow and Apex | [Trigger Actions Framework](https://github.com/mitchspano/trigger-actions-framework) |
| A complete logging product (UI, retention, Flow/LWC logging) | [Nebula Logger](https://github.com/jongpie/NebulaLogger) |
| A small dispatcher, a logger and an agent action pattern you can own outright | HIVE-S |

HIVE-S is not a managed package and has no namespace. Copy it into your project and change it.

## Install

Fresh org:

```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias> --test-level RunLocalTests
```

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com?owner=shivanathd&repo=Hive-S-Salesforce-Enterprise-Design-Pattern)

Upgrading an org that has v1 installed: v2 deletes the v1 classes and fields in the same deploy.

```bash
sf project deploy start --manifest manifest/package.xml \
  --pre-destructive-changes manifest/v1-cleanup/destructiveChanges.xml \
  --target-org <alias> --test-level RunLocalTests
```

Give the people who read logs the **HIVES Log Viewer** permission set.

## Trigger handlers

1. Make the trigger one line, covering every event:

   ```apex
   trigger AccountTrigger on Account (before insert, before update, before delete,
                                      after insert, after update, after delete, after undelete) {
       HIVES_Trigger.run();
   }
   ```

2. Write a handler that overrides only the events you need:

   ```apex
   public with sharing class AccountDefaultsHandler extends HIVES_TriggerHandler {
       public override void beforeInsert(List<SObject> newRecords) {
           for (Account a : (List<Account>) newRecords) {
               a.Rating = a.Rating ?? 'Cold';
           }
       }
   }
   ```

3. Add a **HIVES Trigger Handler** record (custom metadata):

   | Field | Meaning |
   |---|---|
   | Object | API name, e.g. `Account` |
   | Handler Class | The class that extends `HIVES_TriggerHandler` |
   | Execution Order | Lower runs first. Ties run in class-name order |
   | Active | Turns the handler on or off without a deploy |
   | Access Mode | `System` (default) or `User`, passed to the handler as `this.access` |
   | Allow Recursion | Let the handler run again when its own DML fires the same trigger and event |
   | Bypass Permission | A custom permission whose holders skip this handler |

`AccountDefaultsHandler` and its record ship **inactive** as a worked example.

### Access mode

Triggers always run in system mode. `this.access` carries the record's Access Mode, so pass it to
your queries and DML:

```apex
Database.insert(followUps, access);
Database.query(soql, access);
```

From API 67, SOQL and DML that don't name an access level default to **user mode**. That is true
inside handlers too. A `System` handler that writes plain `[SELECT ...]` still runs that query as
the user. Name the mode explicitly.

### Bypassing

| How | Scope |
|---|---|
| **HIVES Data Load Bypass** permission set (grants `HIVES_Bypass_All_Triggers`) | Every handler, for that user. Use it for data loads |
| A handler record's Bypass Permission | That handler, for users holding the permission |
| `HIVES_Trigger.bypass(MyHandler.class)` / `clearBypass` / `clearAllBypasses` | That handler, for the rest of the Apex transaction |

### Errors and recursion

When a handler throws, the error is logged and then rethrown, so the save fails visibly. To give
users a validation message, use `record.addError(...)` instead of throwing.

A handler doesn't re-enter itself for the same object and event unless Allow Recursion is set.
For example, an after-update handler that updates its own object won't run on that nested save.
The guard resets when the handler returns, so later 200-record chunks and partial-success retries
still run. Each skip is logged at DEBUG.

## Logging

```apex
HIVES_Log.error('OrderService', 'Could not reserve stock', e);
HIVES_Log.warn('OrderService', 'Price list missing; using standard');
HIVES_Log.info(...);  HIVES_Log.debug(...);
```

Each entry is written to the debug log. Entries at or above the minimum level are also saved as
**HIVES Log** records, which include the user, the request id and the stack trace. Set the minimum
level with the system property `HIVES.Log.Level` (`ERROR`, `WARN`, `INFO` or `DEBUG`; the default is
`WARN`).

Each saved entry uses one DML statement. Log failures, not every record.

## Agent actions

`HIVES_Actions.runEach` runs a step once per input:

- Each input runs under its own savepoint, so a failed input's writes are rolled back.
- Failures are logged.
- The caller gets an outcome per input, with a readable error ending in `(request <id>)`.
- Validation and custom exception messages are passed through to the caller. System exception text is replaced with a generic message, because an agent may show it to the user.

```apex
List<HIVES_Actions.Outcome> outcomes = HIVES_Actions.runEach('MyAction', inputs, new MyStep());
```

`HIVES_AccountSnapshotAction` is a complete example. It is an `@InvocableMethod` that an Agentforce
agent or a Flow can call: given an Account, it returns open opportunities, pipeline and open cases.
Its queries run `WITH USER_MODE`, so the agent sees only what the user it acts for may see.

## Settings and feature flags

```apex
Integer batchSize = HIVES_Config.getInteger('Orders.BatchSize', 200);
String endpoint   = HIVES_Config.getString('Billing.Endpoint', null);
if (HIVES_Config.isEnabled('NewPricing')) { ... }
HIVES_Config.Environment env = HIVES_Config.environment(); // PRODUCTION, SANDBOX or SCRATCH
```

- **HIVES System Property** records have a Property Name, a Value and an optional Environment. A record that matches the current environment wins over one with no environment, so a single deployment can carry both the production and the sandbox values.
- **HIVES Feature Flag** records turn a feature on when they are active, inside the optional start/end window, and (when a Permission is set) only for users holding that custom permission.

Reads use `getAll()` and cost no SOQL. Detecting the environment costs one query per transaction,
and only when a matching record has an Environment set.

## Testing

```bash
sf apex run test --test-level RunLocalTests --code-coverage --target-org <alias>
scripts/smoke-test.sh <scratch-org-alias>
```

`HIVES_TestData` builds handler, property and flag records for tests, because custom metadata
can't be inserted in a test.

The smoke test runs against a real scratch org and refuses any other kind of org. It deploys real
custom metadata, saves records through the REST API, calls the agent action over its REST
endpoint, and proves that a log survives a rolled-back transaction. It then puts the org back as
it found it.

CI runs [Salesforce Code Analyzer](.github/workflows/code-analyzer.yml) on every pull request and
fails on any high or critical finding.

[docs/DESIGN.md](docs/DESIGN.md) explains how the pieces fit together and why.
[CHANGELOG.md](CHANGELOG.md) lists what changed from v1.

## License

MIT. See [LICENSE](LICENSE).
