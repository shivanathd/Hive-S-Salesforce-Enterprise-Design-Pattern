# Changelog

## 2.0.0

A rewrite for API 68 (Winter '27). The scope is smaller and everything in it is tested and verified
in a live org. To upgrade, use the pre-destructive deploy in the README.

### Fixed from v1

- **Deleting any Account failed** with a null pointer exception. The v1 recursion check looped over `Trigger.new`, which is null on delete.
- **A handler record naming a missing class broke saves at runtime.** It is now reported when tests run, so the deploy fails instead.
- **The recursion guard skipped legitimate work.** With recursion prevention on, processed record ids were kept for the whole transaction, so partial-success retries and second updates to a record were skipped. v2 uses a per-handler depth guard.
- **Database logs were rolled back with the failing transaction.** Logs now go through a Publish Immediately platform event.

### Added

- `HIVES_Actions` and the `HIVES_AccountSnapshotAction` example for Agentforce and Flow: per-input isolation, user-mode queries, and errors returned as data.
- Per-environment settings (production, sandbox, scratch) and permission-gated feature flags.
- Access Mode, Allow Recursion and Bypass Permission on handler records. A bypass-all custom permission and the **HIVES Data Load Bypass** permission set.
- `HIVES_ConfigurationCheckTest`, which fails a deploy that contains a broken handler record.
- `scripts/smoke-test.sh`, an end-to-end check against a real scratch org.
- A Code Analyzer CI workflow.

### Removed

- `HIVES_SecurityUtils`, `HIVES_LimitMonitor`, `HIVES_Logger`, `HIVES_ConfigurationService`, `HIVES_TransactionContext`, `HIVES_IDomainHandler`, `AccountDomainHandler`, and the Service Registry metadata type. Platform features now cover them (`WITH USER_MODE`, `Limits`), or v2 replaces them.
- The fields Context, String Value, Number Value and Boolean Value. One handler class now covers every event, and settings use a single Value field.
- The managed-package namespace. HIVE-S is source you copy into your project.
