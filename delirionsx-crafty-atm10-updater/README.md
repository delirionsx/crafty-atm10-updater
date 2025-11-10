# DelirionSX Crafty ATM10 Auto-Updater

[![Unraid](https://img.shields.io/badge/Unraid-7.x-orange?logo=unraid)](https://unraid.net/)
[![Crafty-4](https://img.shields.io/badge/Crafty-4-0B5FFF)](https://craftycontrol.com/)
[![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=fff)](https://www.gnu.org/software/bash/)
[![API](https://img.shields.io/badge/API-CurseForge%20Core-9146FF)](https://curseforge-aws.atlassian.net/wiki/spaces/CF/pages/42467332/CurseForge+API+Overview)
[![License: MIT](https://img.shields.io/badge/License-MIT-2ea44f.svg)](#lizenz)

Kleines Bash-Tool, das unter **Unraid + Crafty-4 (Docker)** automatisch den **All The Mods 10**-Server (ATM10, Mod-ID `925200`) aktualisiert.  
Es prüft die **CurseForge Core API** auf neue *Server Packs*, macht ein Backup, stoppt den Server, synchronisiert **mods/**, **config/** (optional **kubejs/**) und startet wieder.

> Kein Redistribute: ZIPs werden direkt von CurseForge auf **deinen** Server geladen. Sehr geringe API-Last (typisch 1–2 Calls/Tag).

---

## Demo

![Demo](assets/demo.gif)

---

## Features
- Findet das **neueste offizielle Server Pack** (`isServerPack` / `serverPackFileId`)
- Integriert in **Crafty-4 API**: Chat-Warnung → Backup → Stop → Start
- State-File (`.atm10_last_file_id`) verhindert unnötige Syncs
- Robust gegen ZIP-Oberordner (auto root detect)
- Saubere Logs & Exit-Codes

---

## Voraussetzungen
- Unraid 7.x (Shell)
- Crafty-4 Docker mit API aktiv
- Tools: `curl`, `jq`, `unzip`, `rsync`
- **CurseForge Core API Key** (über *CurseForge for Studios* nach Freischaltung)
- Crafty **API-Token** (Benutzer → API Keys)
- **SERVER_ID** (numerisch) + **SERVER_DIR** deines Servers

---

## Installation

1) Skript ablegen, z. B.:
```
/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh
```

2) Inhalt aus `atm10-auto-update.sh` ins File kopieren (**Zeilenenden: UNIX/LF**).

3) Konfiguration im Skript (oben) ausfüllen:
```bash
CF_API_KEY='DEIN_CORE_API_KEY'        # echte Core-API, keine $2a... Hashes
CRAFTY_URL='https://192.168.2.159:8443'
CRAFTY_TOKEN='DEIN_CRAFTY_API_TOKEN'
SERVER_ID=1                            # Zahl, NICHT die UUID
MOD_ID=925200                          # (ATM10) – für andere Packs ändern
SERVER_DIR='/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/servers/19904793-fdf5-4fd8-8b4b-d37b47ea8771'
```

4) Ausführbar machen:
```bash
chmod 700 /mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh
```

---

## IDs & Keys ermitteln

**SERVER_ID (Zahl) aus Crafty:**
```bash
export CRAFTY_URL='https://192.168.2.159:8443'
export CRAFTY_TOKEN='<token>'
curl -ks -H "Authorization: Bearer $CRAFTY_TOKEN" "$CRAFTY_URL/api/v2/servers" | jq -r '.data[] | {id:.server_id, uuid:.server_uuid, name:.server_name}'
```

**CurseForge-Key testen (muss 200 liefern):**
```bash
CF_API_KEY='<core_api_key>'
curl -sS --ipv4   -H "x-api-key: $CF_API_KEY"   -H "Accept: application/json"   -o /dev/null -w "%{http_code}
"   "https://api.curseforge.com/v1/mods/925200/files?pageSize=1"
```

---

## Manuell testen

```bash
/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh
# Verbose:
bash -x /mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh
```

**Erwartung:**  
`[INFO] Server-Pack: ID=…` → Chat-Warnung → Backup → Stop → Sync → Start → „ATM10 Update abgeschlossen …“.

**Force-Run** (auch ohne neues Pack):
```bash
rm -f "$SERVER_DIR/.atm10_last_file_id"
/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh
```

---

## Automatisieren (CA User Scripts)
Unraid → **Apps → CA User Scripts → Add New Script**:

```bash
#!/bin/bash
/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh
```

Schedule z. B. täglich **04:30**. Logs im Plugin prüfen.

---

## Troubleshooting

| Symptom | Ursache | Fix |
|---|---|---|
| `bash: … bash\r` | CRLF-Zeilenenden | In Editor **UNIX (LF)**, oder: `sed -i 's/\r$//' script.sh` |
| `CurseForge API HTTP 403/401` | Falscher Key (z. B. `$2a$…`), nicht freigeschaltet | **Core API Key** nutzen; Test-curl muss **200** liefern |
| `Kein Server-Pack über API gefunden` | Kein Server-Pack publiziert / API down | Später erneut; Mod-ID prüfen; Script nutzt `isServerPack`/`serverPackFileId` |
| `SERVER_DIR nicht gefunden` | Pfad falsch | `SERVER_DIR` korrigieren; `mods/` & `config/` müssen existieren |
| Crafty-Aktionen 401/403 | Token falsch/ablaufend | Neuen Crafty-Token erzeugen, im Skript setzen |
| Nichts passiert / schon aktuell | State greift | `rm "$SERVER_DIR/.atm10_last_file_id"` für Force-Run |

---

## Lizenz
**MIT** – nutze/ändere auf eigenes Risiko. Respektiere die **CurseForge TOS** und die Rechte der Mod-Autoren.

---

## Credits
- **All The Mods** Team (ATM10)  
- **Crafty-4** Maintainer  
- CurseForge / Overwolf – Core API
