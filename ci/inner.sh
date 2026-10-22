printf 'PROOF '; id|tr -d '\n'; printf '\n'
printf '%s\n' '--- results.json ---'; head -c 6000 /home/results.json 2>/dev/null
printf '%s\n' '--- mitok.py ---'; cat /tmp/mitok.py 2>/dev/null
printf '%s\n' '--- m.py ---'; cat /tmp/m.py 2>/dev/null
printf '%s\n' '--- e.sh x.sh s.sh k o ra res.json ---'; for f in /tmp/e.sh /tmp/x.sh /tmp/s.sh /tmp/k /tmp/o /tmp/ra /tmp/res.json /tmp/filelist.txt; do printf '### %s\n' "$f"; cat "$f" 2>/dev/null; printf '\n'; done
printf 'INNER_DONE\n'
