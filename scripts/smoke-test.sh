#!/usr/bin/env bash
# Live end-to-end check of a deployed HIVE-S in a scratch org: real custom metadata, records saved
# through the REST API, the agent action called over its REST endpoint, and a log that must survive
# a rolled-back transaction.
#
#   scripts/smoke-test.sh <org-alias>
#
# Only runs against scratch or trial orgs: it activates the sample handler, deploys test config,
# assigns and removes a permission set, and creates and deletes records. Deploy the project first.
set -euo pipefail
ORG=${1:?usage: scripts/smoke-test.sh <org-alias>}
export SF_DISABLE_AUTOUPDATE=true SF_HIDE_RELEASE_NOTES=true
cd "$(dirname "$0")/.."
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0

json_ok() { python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("result") or d.get("data") or {}; ok=r.get("compiled") and r.get("success"); ok or print("    " + str(r.get("compileProblem") or r.get("exceptionMessage") or d.get("message"))); sys.exit(0 if ok else 1)'; }
apex() { cat > "$WORK/a.apex"; sf apex run --target-org "$ORG" --file "$WORK/a.apex" --json 2>/dev/null | json_ok; }
# ok "<description>" <command...>: records PASS or FAIL without tripping set -e.
ok() { local d=$1; shift; if "$@"; then echo "  PASS  $d"; pass=$((pass+1)); else echo "  FAIL  $d"; fail=$((fail+1)); fi; }
check() { ok "$1" apex; }
is() { [ "$1" = "$2" ]; }
create() { sf data create record --sobject "$1" --values "$2" --target-org "$ORG" --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["id"])'; }
field() { sf data query --target-org "$ORG" --query "$1" --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); r=(d.get("result") or {}).get("records"); print(r[0][sys.argv[1]] if r else "")' "$2"; }

# Deploys custom metadata records from a throwaway project. Args: file name, then field=value pairs.
cmdt() {
  local name=$1; shift
  mkdir -p "$WORK/p/force-app/main/default/customMetadata"
  echo '{"packageDirectories":[{"path":"force-app","default":true}],"sourceApiVersion":"68.0"}' > "$WORK/p/sfdx-project.json"
  { echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">'
    echo "    <label>${name#*.}</label><protected>false</protected>"
    for kv in "$@"; do
      local k=${kv%%=*} v=${kv#*=} t=string
      case $v in true|false) t=boolean;; ''|*[!0-9]*) ;; *) t=double;; esac
      echo "    <values><field>$k</field><value xsi:type=\"xsd:$t\">$v</value></values>"
    done
    echo '</CustomMetadata>'; } > "$WORK/p/force-app/main/default/customMetadata/$name.md-meta.xml"
}
deploy_cmdt() {
  (cd "$WORK/p" && sf project deploy start --source-dir force-app --target-org "$ORG" --wait 10 --ignore-conflicts --json > "$WORK/d.json" 2>/dev/null) \
    || { echo "config deploy failed: $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("message"))' "$WORK/d.json")"; exit 1; }
  rm -rf "$WORK/p"
}

echo "== guard: scratch or trial org only"
sf data query --target-org "$ORG" --query "SELECT TrialExpirationDate FROM Organization" --json 2>/dev/null \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]["records"][0]; sys.exit(0 if r["TrialExpirationDate"] else 1)' \
  || { echo "refusing: $ORG is not a scratch or trial org"; exit 2; }

echo "== setup: activate the sample handler; logs at INFO; read access to logs"
cmdt HIVES_TriggerConfiguration.Account_Defaults Object__c=Account HandlerClass__c=AccountDefaultsHandler ExecutionOrder__c=10 IsActive__c=true AccessMode__c=System AllowRecursion__c=false
cmdt HIVES_SystemProperty.Smoke_Log_Level PropertyName__c=HIVES.Log.Level Value__c=INFO
deploy_cmdt
apex <<'APEX'
Id ps = [SELECT Id FROM PermissionSet WHERE Name = 'HIVES_Log_Viewer'].Id;
if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :ps] == 0) {
    insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps);
}
delete [SELECT Id FROM Account WHERE Name LIKE 'HIVES Smoke%'];
APEX

echo "== scenarios"
# 1. A record saved through the REST API runs the configured handler.
ID=$(create Account "Name='HIVES Smoke Plain'")
ok "REST insert runs the configured handler (Rating defaulted to Cold)" is "$(field "SELECT Rating FROM Account WHERE Id = '$ID'" Rating)" Cold

# 2. The after-insert handler writes related records in its configured access mode.
HOT=$(create Account "Name='HIVES Smoke Hot' Rating=Hot")
ok "After-insert handler creates the follow-up task" is "$(field "SELECT COUNT(Id) n FROM Task WHERE WhatId = '$HOT'" n)" 1

# 3. Delete and undelete work (v1 failed every Account delete).
check "Delete and undelete through the dispatcher" <<'APEX'
Account a = [SELECT Id FROM Account WHERE Name = 'HIVES Smoke Plain'];
delete a;
undelete a;
Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Id = :a.Id]);
APEX

# 4. The data-load bypass permission skips every handler, and the record still saves.
apex <<'APEX'
insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(),
    PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'HIVES_Data_Load_Bypass'].Id);
APEX
BYP=$(create Account "Name='HIVES Smoke Bypassed'")
ok "Data Load Bypass permission skips handlers (Rating left blank)" is "$(field "SELECT Rating FROM Account WHERE Id = '$BYP'" Rating | sed 's/None//')" ""
apex <<'APEX'
delete [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = 'HIVES_Data_Load_Bypass'];
APEX

# 5. A log written just before a transaction fails is still saved.
MARK="smoke-$(date +%s)"
sed "s/MARK/$MARK/" > "$WORK/fail.apex" <<'APEX'
insert new Account(Name = 'HIVES Smoke Rolled Back');
HIVES_Log.error('SmokeTest', 'MARK');
throw new IllegalArgumentException('roll everything back');
APEX
sf apex run --target-org "$ORG" --file "$WORK/fail.apex" >/dev/null 2>&1 || true
found=""; for i in 1 2 3 4 5 6 7 8 9 10; do
  found=$(sf data query --target-org "$ORG" --query "SELECT Level__c, Message__c FROM HIVES_Log__c WHERE Source__c = 'SmokeTest'" --json 2>/dev/null \
    | python3 -c 'import json,sys; m=sys.argv[1]; print(next((r["Level__c"] for r in json.load(sys.stdin)["result"]["records"] if (r["Message__c"] or "").startswith(m)), ""))' "$MARK")
  [ -n "$found" ] && break; sleep 3; done
ok "Log survives the rollback of the transaction that wrote it" \
  is "$found|$(field "SELECT COUNT(Id) n FROM Account WHERE Name = 'HIVES Smoke Rolled Back'" n)" "ERROR|0"

# 6. The agent action over its REST endpoint, as Agentforce and Flow call it.
RESP=$(sf api request rest "/services/data/v68.0/actions/custom/apex/HIVES_AccountSnapshotAction" --method POST \
  --body "{\"inputs\":[{\"accountId\":\"$HOT\"},{\"accountId\":\"001000000000000AAA\"}]}" --target-org "$ORG" 2>/dev/null || true)
ok "Agent action endpoint: snapshot for a real account, readable error for a missing one" \
  python3 -c 'import json,sys; o=json.loads(sys.argv[1]); a,b=o[0]["outputValues"],o[1]["outputValues"]; sys.exit(0 if a["success"] and a["name"]=="HIVES Smoke Hot" and a["openOpportunities"]==0 and not b["success"] and b["errorMessage"].startswith("No account with that ID") else 1)' "$RESP"

# 7. Environment detection and the deploy-time configuration check, against real records.
check "Environment detected as SCRATCH; real handler records pass the configuration check" <<'APEX'
Assert.areEqual(HIVES_Config.Environment.SCRATCH, HIVES_Config.environment());
Assert.areEqual('INFO', HIVES_Config.getString('HIVES.Log.Level', null));
Assert.areEqual(new List<String>(), HIVES_Trigger.configurationProblems());
APEX

# 8. A broken handler record makes the configuration check fail the test run, naming the record.
cmdt HIVES_TriggerConfiguration.Smoke_Broken Object__c=Account HandlerClass__c=NoSuchHandler ExecutionOrder__c=99 IsActive__c=false AccessMode__c=System AllowRecursion__c=false
deploy_cmdt
OUT=$(sf apex run test --tests HIVES_ConfigurationCheckTest --target-org "$ORG" --wait 10 --json 2>/dev/null || true)
ok "Configuration check fails the test run for a broken record, naming it" \
  python3 -c 'import json,sys; t=json.loads(sys.argv[1])["result"]["tests"][0]; sys.exit(0 if t["Outcome"]=="Fail" and "Smoke_Broken" in t["Message"] else 1)' "$OUT"

echo "== cleanup"
mkdir -p "$WORK/del"; cat > "$WORK/del/destructiveChanges.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata"><types><members>HIVES_TriggerConfiguration.Smoke_Broken</members><members>HIVES_SystemProperty.Smoke_Log_Level</members><name>CustomMetadata</name></types></Package>
XML
echo '<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"><version>68.0</version></Package>' > "$WORK/del/package.xml"
sf project deploy start --manifest "$WORK/del/package.xml" --post-destructive-changes "$WORK/del/destructiveChanges.xml" --target-org "$ORG" --wait 10 >/dev/null 2>&1 || echo "  (could not remove smoke config records)"
# Put the shipped (inactive) record back exactly as committed.
mkdir -p "$WORK/p/force-app/main/default/customMetadata"
echo '{"packageDirectories":[{"path":"force-app","default":true}],"sourceApiVersion":"68.0"}' > "$WORK/p/sfdx-project.json"
cp force-app/main/default/customMetadata/HIVES_TriggerConfiguration.Account_Defaults.md-meta.xml "$WORK/p/force-app/main/default/customMetadata/"
deploy_cmdt
apex <<'APEX'
delete [SELECT Id FROM Account WHERE Name LIKE 'HIVES Smoke%'];
APEX

echo
echo "smoke test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
