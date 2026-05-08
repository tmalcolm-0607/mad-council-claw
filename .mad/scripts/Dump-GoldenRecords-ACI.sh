#!/bin/bash
# Pulls the full hierarchy for the 10 persisted golden records from NPE Cosmos.
# Runs inside ACI (VNet-injected) with managed-identity auth.
#
# OUTPUT FORMAT: each record is dumped as gzip+base64 single-line block to fit all
# 10 records under the `az container logs` size limit (~16KB tail). Decode locally:
#   echo "<base64>" | base64 -d | gunzip | python -m json.tool

set -euo pipefail
LAST_COSMOS_STATUS=""

CASE_IDS=(
  "LNS-1777401094-BFW6ZACN"
  "LNS-1777401207-XO5DSFIV"
)
# Adds Events (lifecycle audit trail — ~8 events per case from create+patch operations).
# Communications/Aggregates are empty for these caseIds (test doesn't exercise them) — skipped.
EXTRA_CONTAINERS=(Events)

echo "=== LENS-CMS NPE Golden-Record Dump (gzip+base64) ==="
echo "Cosmos: $COSMOS_ENDPOINT"
echo "Records: ${#CASE_IDS[@]}"
echo ""

# az login + token
echo "--- az login --identity ---"
if ! login_out=$(az login --identity --client-id "$CLIENT_ID" 2>&1); then
    echo "FATAL: az login failed: $login_out"; exit 1
fi
echo "PASS : az login OK"

get_token() {
    local res="$1" max=4 attempt out tok
    for attempt in $(seq 1 $max); do
        if out=$(az account get-access-token --resource "$res" --query accessToken -o tsv 2>&1); then
            tok="$out"; if [ -n "$tok" ] && [ "$tok" != "None" ]; then echo "$tok"; return 0; fi
        fi
        if [ "$attempt" -lt "$max" ]; then sleep $((attempt * 5)); fi
    done
    return 1
}

COSMOS_RESOURCE=$(echo "$COSMOS_ENDPOINT" | sed 's/:443$//')
COSMOS_TOKEN=$(get_token "$COSMOS_RESOURCE")
if [ -z "$COSMOS_TOKEN" ]; then echo "FATAL: no cosmos token"; exit 1; fi
echo "PASS : Cosmos token acquired (${#COSMOS_TOKEN} chars)"
echo ""

cosmos_query() {
    local container="$1" query="$2" pk="$3"
    local status_code
    status_code=$(curl -s -o /tmp/cosmos_body.txt -w "%{http_code}" --max-time 30 \
        -H "Authorization: type=aad&ver=1.0&sig=$COSMOS_TOKEN" \
        -H "Content-Type: application/query+json" \
        -H "x-ms-documentdb-isquery: True" \
        -H "x-ms-documentdb-partitionkey: [\"$pk\"]" \
        -H "x-ms-version: 2018-12-31" \
        -X POST "${COSMOS_ENDPOINT}/dbs/CMS/colls/${container}/docs" \
        -d "$query" 2>/dev/null) || status_code="ERR"
    LAST_COSMOS_STATUS="$status_code"
}

# For each record: aggregate all 4 containers into a single JSON,
# then gzip + base64 to a single line.
for cid in "${CASE_IDS[@]}"; do
    # Build per-container JSON files
    declare -A QSTAT
    for container in Cases Dfts Notes Attachments "${EXTRA_CONTAINERS[@]}"; do
        QUERY=$(printf '{"query":"SELECT * FROM c WHERE c.caseId = @cid","parameters":[{"name":"@cid","value":"%s"}]}' "$cid")
        cosmos_query "$container" "$QUERY" "$cid"
        QSTAT[$container]="${LAST_COSMOS_STATUS:-unknown}"
        # Save per-container body
        cp /tmp/cosmos_body.txt "/tmp/dump_${container}.json" 2>/dev/null || echo '{}' > "/tmp/dump_${container}.json"
    done

    # Aggregate via python
    AGG_FILE="/tmp/agg_${cid}.json"
    python3 - <<PYEOF > "$AGG_FILE"
import json
all_containers = ("Cases", "Dfts", "Notes", "Attachments", "Events")
qstat = {"Cases": "${QSTAT[Cases]}", "Dfts": "${QSTAT[Dfts]}", "Notes": "${QSTAT[Notes]}", "Attachments": "${QSTAT[Attachments]}", "Events": "${QSTAT[Events]:-na}"}
agg = {"caseId": "$cid", "queryStatus": qstat, "containers": {}}
for container in all_containers:
    try:
        with open(f"/tmp/dump_{container}.json") as f:
            agg["containers"][container] = json.load(f)
    except Exception as e:
        agg["containers"][container] = {"error": str(e)}
print(json.dumps(agg, separators=(",", ":")))
PYEOF

    # Emit framed gzip+base64 block
    SIZE=$(wc -c < "$AGG_FILE")
    echo "RECORD-START: $cid (raw=$SIZE bytes)"
    gzip -c -9 "$AGG_FILE" | base64 -w 0
    echo ""
    echo "RECORD-END: $cid"
    echo ""
done

echo "=== DUMP COMPLETE ==="
