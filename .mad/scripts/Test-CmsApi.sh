#!/bin/bash
# LENS-CMS API Smoke Test - Kudu SSH (Linux App Service)
# Uses the App Service managed identity to get an app-only token (idtyp=app)
#
# Usage: Run from Kudu SSH at https://app-cms-npe-tonym.scm.azurewebsites.net/webssh/host
#   bash /home/site/test.sh
# Or paste commands directly into Kudu SSH terminal.

set -e

BASE_URL="${BASE_URL:-https://app-cms-npe-tonym.azurewebsites.net}"
RESOURCE="${RESOURCE:-api://6c5a00ce-8062-49d8-b568-b9bd0363340b}"
PASS=0
FAIL=0

log_pass() { echo "PASS : $1"; PASS=$((PASS + 1)); }
log_fail() { echo "FAIL : $1"; FAIL=$((FAIL + 1)); }

echo "=== LENS-CMS API Smoke Test ==="
echo "Base URL: $BASE_URL"
echo ""

# Step 0: Get managed identity token
echo "--- Acquiring MI token ---"
TOKEN_RESPONSE=$(curl -s -H "X-IDENTITY-HEADER: $IDENTITY_HEADER" \
  "${IDENTITY_ENDPOINT}?resource=${RESOURCE}&api-version=2019-08-01")
TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || true)

if [ -z "$TOKEN" ]; then
  echo "FAIL : Could not acquire MI token"
  echo "Response: $TOKEN_RESPONSE"
  echo ""
  echo "If IDENTITY_ENDPOINT is empty, you're not running inside the App Service."
  echo "Set TOKEN manually: export TOKEN=<your-bearer-token>"
  exit 1
fi
echo "PASS : MI token acquired (${#TOKEN} chars)"
echo ""

# Test 1: Health (no auth)
echo "--- Test 1: Health ---"
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/health")
if [ "$HEALTH_CODE" = "200" ]; then
  log_pass "Health - HTTP $HEALTH_CODE"
else
  log_fail "Health - HTTP $HEALTH_CODE"
fi

# Test 2: List Cases
echo "--- Test 2: List Cases ---"
LIST_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL/api/v1/cases?pageSize=5")
LIST_CODE=$(echo "$LIST_RESP" | tail -1)
LIST_BODY=$(echo "$LIST_RESP" | sed '$d')
if [ "$LIST_CODE" = "200" ]; then
  log_pass "ListCases - HTTP $LIST_CODE"
  echo "  Body: $(echo "$LIST_BODY" | head -c 200)"
else
  log_fail "ListCases - HTTP $LIST_CODE"
  echo "  Body: $LIST_BODY"
fi

# Test 3: Create Case
echo "--- Test 3: Create Case ---"
CREATE_BODY='{"requestType":"LegalEnforcement","title":"Smoke Test Case","jurisdiction":"US","description":"Automated smoke test"}'
CREATE_RESP=$(curl -s -w "\n%{http_code}" -D /tmp/create_headers.txt \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$BASE_URL/api/v1/cases" \
  -d "$CREATE_BODY")
CREATE_CODE=$(echo "$CREATE_RESP" | tail -1)
CREATE_RESP_BODY=$(echo "$CREATE_RESP" | sed '$d')

if [ "$CREATE_CODE" = "201" ]; then
  CASE_ID=$(echo "$CREATE_RESP_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('caseId',''))" 2>/dev/null || true)
  ETAG=$(grep -i "etag" /tmp/create_headers.txt 2>/dev/null | sed 's/[Ee][Tt][Aa][Gg]: *//' | tr -d '\r\n' || true)
  log_pass "CreateCase - HTTP $CREATE_CODE caseId=$CASE_ID"
  echo "  ETag: $ETAG"
else
  log_fail "CreateCase - HTTP $CREATE_CODE"
  echo "  Body: $CREATE_RESP_BODY"
  CASE_ID=""
fi

if [ -n "$CASE_ID" ]; then
  # Test 4: Get Case
  echo "--- Test 4: Get Case ---"
  GET_RESP=$(curl -s -w "\n%{http_code}" -D /tmp/get_headers.txt \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE_URL/api/v1/cases/$CASE_ID")
  GET_CODE=$(echo "$GET_RESP" | tail -1)
  GET_BODY=$(echo "$GET_RESP" | sed '$d')

  if [ "$GET_CODE" = "200" ]; then
    GET_ETAG=$(grep -i "etag" /tmp/get_headers.txt 2>/dev/null | sed 's/[Ee][Tt][Aa][Gg]: *//' | tr -d '\r\n' || true)
    log_pass "GetCase - HTTP $GET_CODE"
    echo "  ETag: $GET_ETAG"
  else
    log_fail "GetCase - HTTP $GET_CODE"
    echo "  Body: $GET_BODY"
  fi

  # Test 5: Patch Case
  echo "--- Test 5: Patch Case ---"
  PATCH_BODY='[{"op":"replace","path":"/title","value":"Updated Smoke Test"}]'
  PATCH_ETAG="${GET_ETAG:-$ETAG}"
  PATCH_RESP=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json-patch+json" \
    -H "If-Match: $PATCH_ETAG" \
    -X PATCH "$BASE_URL/api/v1/cases/$CASE_ID" \
    -d "$PATCH_BODY")
  PATCH_CODE=$(echo "$PATCH_RESP" | tail -1)
  PATCH_RESP_BODY=$(echo "$PATCH_RESP" | sed '$d')

  if [ "$PATCH_CODE" = "200" ]; then
    log_pass "PatchCase - HTTP $PATCH_CODE"
  else
    log_fail "PatchCase - HTTP $PATCH_CODE"
    echo "  Body: $PATCH_RESP_BODY"
  fi

fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
