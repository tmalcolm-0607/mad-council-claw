#!/bin/bash
# Augment 10 existing NPE golden records with: a 2nd DFT (Teams + phoneNumber)
# and 1 Communication (LE outbound delivery notice with 2 participants).
#
# Runs inside ACI (VNet-injected) with managed-identity auth.

set -uo pipefail
# NOTE: -e disabled — get_token function returns non-zero in some retry paths and we
# want explicit error handling, not silent script death.

CASE_IDS=(
  "LNS-1777398033-CLTJKX1T"
  "LNS-1777399131-0Z7FF32U"
  "LNS-1777399270-B49EKUQN"
  "LNS-1777399426-SZQIXRCV"
  "LNS-1777399544-QN1DZKQI"
  "LNS-1777400746-OMF476P3"
  "LNS-1777400875-A4YUGW4L"
  "LNS-1777400983-KG9EFT5C"
  "LNS-1777401094-BFW6ZACN"
  "LNS-1777401207-XO5DSFIV"
)

PASS=0; FAIL=0
log_pass() { echo "PASS : $1"; PASS=$((PASS + 1)); }
log_fail() { echo "FAIL : $1 — $2"; FAIL=$((FAIL + 1)); }

echo "=== LENS-CMS NPE Golden-Record Augmenter ==="
echo "Base URL: $BASE_URL"
echo "Resource: $RESOURCE"
echo "Records to augment: ${#CASE_IDS[@]}"
echo ""

# az login + token
echo "--- az login --identity ---"
if ! login_out=$(az login --identity --client-id "$CLIENT_ID" 2>&1); then
    echo "FATAL: az login failed: $login_out"; exit 1
fi
echo "PASS : az login OK"

get_token() {
    # Tries api://<guid> first, then bare <guid> (per FullField script's acquire_token_for —
    # az get-access-token sometimes intermittently returns parse errors on the api:// form).
    local res="$1" max=4 attempt out tok bare
    bare="${res#api://}"
    for attempt in $(seq 1 $max); do
        # Form 1: api://<guid>
        if out=$(az account get-access-token --resource "$res" --query accessToken -o tsv 2>&1); then
            tok="$out"; if [ -n "$tok" ] && [ "$tok" != "None" ]; then echo "$tok"; return 0; fi
        else
            echo "  attempt $attempt: az get-access-token (res='$res') failed — $(echo "$out" | head -c 120)" >&2
        fi
        # Form 2 fallback: bare <guid>
        if [ "$bare" != "$res" ]; then
            if out=$(az account get-access-token --resource "$bare" --query accessToken -o tsv 2>&1); then
                tok="$out"; if [ -n "$tok" ] && [ "$tok" != "None" ]; then echo "$tok"; return 0; fi
            else
                echo "  attempt $attempt: az get-access-token (bare='$bare') failed — $(echo "$out" | head -c 120)" >&2
            fi
        fi
        if [ "$attempt" -lt "$max" ]; then sleep $((attempt * 5)); fi
    done
    return 1
}

echo "--- Acquiring API token ---"
TOKEN=$(get_token "$RESOURCE" 2>&1) || true
if [ -z "${TOKEN:-}" ]; then
    echo "FATAL: no API token (resource=$RESOURCE)"
    echo "  Trying once more with verbose output:"
    az account get-access-token --resource "$RESOURCE" 2>&1 | head -10 || true
    exit 1
fi
echo "PASS : API token acquired (${#TOKEN} chars)"
echo ""

AUTH_HEADER="Authorization: Bearer $TOKEN"

for cid in "${CASE_IDS[@]}"; do
    echo "================================================================="
    echo "AUGMENT-RECORD: $cid"
    echo "================================================================="

    # ------- POST DFT 2 -------
    DFT2_IDEM=$(cat /proc/sys/kernel/random/uuid)
    # NOTE: CreateDftRequest validator requires `caseId` IN THE BODY (line 27-29) even though
    # the route already contains it. Easy to miss because the controller takes both `[FromRoute]
    # caseId` and `[FromBody] CreateDftRequest request`, and the validator runs on the body.
    DFT2_BODY='{
      "caseId": "'"$cid"'",
      "service": "Teams",
      "targetIdentifierValue": "+1-555-0199",
      "identifierType": "PhoneNumber",
      "scenario": "LegalDemand",
      "etsiTaskId": "ETSI-TASK-AUG-'"$cid"'",
      "dataCategories": [
        {"categoryType": "TransactionalData", "service": "Teams"},
        {"categoryType": "AuthenticationLogs", "service": "Teams"}
      ]
    }'

    # Write body to a file and pass via -d @file to avoid any shell-level quoting issues.
    echo "$DFT2_BODY" > /tmp/dft2_req.json
    REQ_BYTES=$(wc -c < /tmp/dft2_req.json)
    echo "  DFT 2 request body file: /tmp/dft2_req.json ($REQ_BYTES bytes)"
    DFT2_CODE=$(curl -s -o /tmp/dft2_body.txt -w "%{http_code}" -D /tmp/dft2_headers.txt \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: $DFT2_IDEM" \
        -X POST "$BASE_URL/api/v1/cases/$cid/dfts" \
        -d @/tmp/dft2_req.json)
    DFT2_BODY_RESP=$(cat /tmp/dft2_body.txt 2>/dev/null || echo "")
    if [ "$DFT2_CODE" = "201" ]; then
        DFT2_ID=$(echo "$DFT2_BODY_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lensTaskId',''))" 2>/dev/null) || true
        log_pass "DFT 2 created — $DFT2_ID (Teams/PhoneNumber, 2 DataCategories: TransactionalData, AuthenticationLogs)"
    else
        echo "  DFT 2 response headers (first 500): $(head -c 500 /tmp/dft2_headers.txt 2>/dev/null | tr '\n' ' ')"
        log_fail "DFT 2 create" "HTTP $DFT2_CODE — body[0:500]=$(head -c 500 /tmp/dft2_body.txt 2>/dev/null)"
    fi

    # ------- POST Communication -------
    COMM_IDEM=$(cat /proc/sys/kernel/random/uuid)
    COMM_BODY='{
      "caseId": "'"$cid"'",
      "direction": "Outbound",
      "channel": "Email",
      "communicationType": "Delivery",
      "subject": "LENS-CMS — Production delivery notice for case '"$cid"'",
      "body": "This message confirms data delivery for case '"$cid"'. Refer to the attached production package for details.",
      "participants": [
        {"name": "LENS-CMS Service", "email": "lens-cms-service@microsoft.com", "type": "Sender"},
        {"name": "FBI Seattle Field Office", "email": "agent-fbi-1138@fbi.gov", "type": "Recipient"},
        {"name": "U.S. Attorney WDWA", "email": "usao-wdwa@usdoj.gov", "type": "CC"}
      ],
      "attachmentIds": [],
      "templateId": "delivery-notice-v1"
    }'

    echo "$COMM_BODY" > /tmp/comm_req.json
    COMM_CODE=$(curl -s -o /tmp/comm_body.txt -w "%{http_code}" -D /tmp/comm_headers.txt \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -H "X-Idempotency-Key: $COMM_IDEM" \
        -X POST "$BASE_URL/api/v1/cases/$cid/communications" \
        -d @/tmp/comm_req.json)
    COMM_BODY_RESP=$(cat /tmp/comm_body.txt 2>/dev/null || echo "")
    if [ "$COMM_CODE" = "201" ]; then
        COMM_ID=$(echo "$COMM_BODY_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('communicationId',''))" 2>/dev/null) || true
        log_pass "Communication created — $COMM_ID (Outbound/Email/Delivery, 3 participants)"
    else
        echo "  Communication response headers: $(head -c 400 /tmp/comm_headers.txt 2>/dev/null | tr '\n' ' ')"
        log_fail "Communication create" "HTTP $COMM_CODE — body[0:500]=$(head -c 500 /tmp/comm_body.txt 2>/dev/null)"
    fi

    echo ""
done

echo "================================================================="
echo "Summary: $PASS passed, $FAIL failed (records: ${#CASE_IDS[@]})"
echo "=== AUGMENT COMPLETE ==="
