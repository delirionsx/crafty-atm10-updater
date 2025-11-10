#!/usr/bin/env bash
set -euo pipefail

# ====== KONFIG ======
CF_API_KEY='<DEIN_NEUER_DEV_API_KEY>'        # Core API Key aus CurseForge for Studios – in EINZELNEN Quotes
CRAFTY_URL='https://192.168.2.159:8443'
CRAFTY_TOKEN='<DEIN_NEUER_CRAFTY_API_TOKEN>' # in EINZELNEN Quotes
SERVER_ID=1                                   # numerisch! (z. B. 1)
MOD_ID=925200

# Dein Server-Ordner (UUID)
SERVER_DIR='/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/servers/19904793-fdf5-4fd8-8b4b-d37b47ea8771'

# Self-signed nur für Crafty; für CurseForge NICHT nötig
CURL_TLS=(-k)

# ====== CHECKS ======
[[ -d "$SERVER_DIR" ]] || { echo "[FEHLER] SERVER_DIR nicht gefunden: $SERVER_DIR"; exit 1; }
for bin in curl jq unzip rsync; do
  command -v "$bin" >/dev/null || { echo "[FEHLT] $bin"; exit 1; }
done

# ====== HELPERS ======
auth=(-H "Authorization: Bearer ${CRAFTY_TOKEN}")

say(){ msg="$*"; curl -s "${CURL_TLS[@]}" "${auth[@]}" -X POST \
  "${CRAFTY_URL}/api/v2/servers/${SERVER_ID}/stdin" --data "say ${msg}" >/dev/null || true; }
action(){ act="$1"; curl -s "${CURL_TLS[@]}" "${auth[@]}" -X POST \
  "${CRAFTY_URL}/api/v2/servers/${SERVER_ID}/action/${act}" >/dev/null; }

# Für CurseForge-API IMMER Header direkt mitschicken (keine Arrays!)
cf_api() {
  curl -sS --ipv4 \
    -H "x-api-key: ${CF_API_KEY}" \
    -H "Accept: application/json" \
    -H "User-Agent: atm10-updater/1.0" \
    "$@"
}

# ====== TEMPFILES & TRAP ======
tmp_json="$(mktemp)"
tmp_dl="$(mktemp)"
tmp_zip="$(mktemp)"
staging=""
trap '[[ -f "$tmp_json" ]] && rm -f "$tmp_json"; \
      [[ -f "$tmp_dl"   ]] && rm -f "$tmp_dl"; \
      [[ -f "$tmp_zip"  ]] && rm -f "$tmp_zip"; \
      [[ -n "$staging" && -d "$staging" ]] && rm -rf "$staging"' EXIT

# ====== NEUSTES ATM10 SERVER-PACK FINDEN (API-Flags) ======
status=$(cf_api -w "%{http_code}" -o "$tmp_json" \
  "https://api.curseforge.com/v1/mods/${MOD_ID}/files?pageSize=500")

if [[ "$status" != "200" ]]; then
  echo "[FEHLER] CurseForge API HTTP $status"
  tail -n 50 "$tmp_json"
  exit 1
fi

# 1) echte Server-Packs
file_id=$(jq -r '
  [.data[] | select(.isServerPack == true)]
  | sort_by(.fileDate) | last | .id // empty
' "$tmp_json")

# 2) Falls leer: über serverPackFileId
if [[ -z "$file_id" || "$file_id" == "null" ]]; then
  file_id=$(jq -r '
    [.data[] | select(.serverPackFileId != null)]
    | sort_by(.fileDate) | last | .serverPackFileId // empty
  ' "$tmp_json")
fi

# 3) Fallback: Namensmuster
if [[ -z "$file_id" || "$file_id" == "null" ]]; then
  file_id=$(jq -r '
    [.data[] | select(.fileName | test("(Server.?Files|Server.?-?Files|Server.?Pack|serverpack)"; "i"))]
    | sort_by(.fileDate) | last | .id // empty
  ' "$tmp_json")
fi

[[ -n "$file_id" && "$file_id" != "null" ]] || { echo "[ABBRUCH] Kein Server-Pack über API gefunden."; exit 1; }

file_name=$(jq -r ".data[] | select(.id == ${file_id}) | .fileName" "$tmp_json")
echo "[INFO] Server-Pack: ID=${file_id} (${file_name})"

# ====== DOWNLOAD-URL ======
dl_status=$(cf_api -w "%{http_code}" -o "$tmp_dl" \
  "https://api.curseforge.com/v1/mods/${MOD_ID}/files/${file_id}/download-url")
[[ "$dl_status" == "200" ]] || { echo "[FEHLER] Download-URL HTTP $dl_status"; cat "$tmp_dl"; exit 1; }
dl_url=$(jq -r '.data' "$tmp_dl")
[[ -n "$dl_url" && "$dl_url" != "null" ]] || { echo "[FEHLER] Keine Download-URL erhalten."; exit 1; }

# ====== STATE-CHECK ======
state_file="${SERVER_DIR}/.atm10_last_file_id"
if [[ -f "$state_file" && "$(cat "$state_file")" == "$file_id" ]]; then
  echo "[OK] ATM10 bereits aktuell (File ID ${file_id})."
  exit 0
fi

# ====== WARNEN + BACKUP + STOP ======
say "§eATM10 Update: Server wird in 30s für Wartung gestoppt."
sleep 30
action backup_server
action stop_server
sleep 10

# ====== DOWNLOAD + ENTZIP + ROOT-AUTO-DETECT ======
curl -L --ipv4 --fail --retry 3 --retry-delay 2 -o "$tmp_zip" "$dl_url"
staging="$(mktemp -d)"
unzip -q "$tmp_zip" -d "$staging"
root_candidate="$(find "$staging" -maxdepth 2 -type d -name mods -printf '%h\n' -quit)"
[[ -n "$root_candidate" ]] && staging="$root_candidate"

# ====== SYNC ======
[[ -d "${staging}/mods"   ]] && rsync -a --delete "${staging}/mods/"   "${SERVER_DIR}/mods/"
[[ -d "${staging}/config" ]] && rsync -a --delete "${staging}/config/" "${SERVER_DIR}/config/"
[[ -d "${staging}/kubejs" ]] && rsync -a --delete "${staging}/kubejs/" "${SERVER_DIR}/kubejs/"

echo "${file_id}" > "$state_file"

# ====== START ======
action start_server
say "§aATM10 Update abgeschlossen. (File ID ${file_id})"
echo "[FERTIG] ATM10 aktualisiert (File ID ${file_id})."
