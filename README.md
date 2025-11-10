DelirionSX Crafty ATM10 Auto-Updater

Kleines Bash-Tool, das unter Unraid + Crafty-4 (Docker) automatisch den All The Mods 10-Server (ATM10, Mod-ID 925200) aktualisiert.
Es prüft die CurseForge Core API auf neue Server Packs, macht ein Backup, stoppt den Server, synchronisiert mods/, config/ (optional kubejs/) und startet wieder.

Kein Redistribute: ZIPs werden direkt von CurseForge auf deinen Server geladen. Sehr geringe API-Last (typisch 1–2 Calls/Tag).

Features

Findet das neueste offizielle Server Pack (per isServerPack / serverPackFileId)

Integriert in Crafty-4 API: Chat-Warnung → Backup → Stop → Start

State-File (.atm10_last_file_id) verhindert unnötige Syncs

Robust gegen ZIP-Oberordner (auto root detect)

Saubere Logs & Exit-Codes

Voraussetzungen

Unraid 7.x (Shell)

Crafty-4 Docker mit API aktiv

Tools: curl, jq, unzip, rsync

Falls jq fehlt: statische Binary nutzen und symlink setzen.

CurseForge Core API Key (über CurseForge for Studios nach Freischaltung)

Crafty API-Token (Benutzer → API Keys)

SERVER_ID (numerisch) + SERVER_DIR deines Servers

Installation

Skript anlegen (Pfad-Beispiel):

/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/scripts/atm10-auto-update.sh


Inhalt (Script liegt bereits im Repo unter atm10-auto-update.sh) auf den Server kopieren.
Wichtig: In deinem Editor UNIX (LF) als Zeilenende verwenden.
Check auf dem Server:

sed -n '1p' /mnt/.../atm10-auto-update.sh   # sollte mit "#!/usr/bin/env bash" beginnen


Konfiguration im Skript (oben) ausfüllen:

CF_API_KEY='DEIN_CORE_API_KEY'        # echte Core-API, keine $2a... Hashes
CRAFTY_URL='https://<deine-unraid-ip>:8443'
CRAFTY_TOKEN='DEIN_CRAFTY_API_TOKEN'
SERVER_ID=1                            # Zahl, NICHT die UUID
MOD_ID=925200                          # (ATM10) – anpassbar für andere Packs
SERVER_DIR='/mnt/.../servers/<dein-server-uuid>'


Ausführbar machen:

chmod 700 /mnt/.../atm10-auto-update.sh

IDs & Keys ermitteln

SERVER_ID (Zahl) aus Crafty:

export CRAFTY_URL='https://<ip>:8443'
export CRAFTY_TOKEN='<token>'
curl -ks -H "Authorization: Bearer $CRAFTY_TOKEN" "$CRAFTY_URL/api/v2/servers" \
| jq -r '.data[] | {id:.server_id, uuid:.server_uuid, name:.server_name}'


CurseForge-Key testen (muss 200 liefern):

CF_API_KEY='<core_api_key>'
curl -sS --ipv4 \
  -H "x-api-key: $CF_API_KEY" \
  -H "Accept: application/json" \
  "https://api.curseforge.com/v1/mods/925200/files?pageSize=1" \
  -o /dev/null -w "%{http_code}\n"

Manuell testen
/mnt/.../atm10-auto-update.sh
# Verbose:
bash -x /mnt/.../atm10-auto-update.sh


Erwartung:
[INFO] Server-Pack: ID=… → Chat-Warnung → Backup → Stop → Sync → Start → „ATM10 Update abgeschlossen …“.

Force-Run (auch ohne neues Pack):

rm -f "$SERVER_DIR/.atm10_last_file_id"
/mnt/.../atm10-auto-update.sh

Automatisieren (CA User Scripts)

Unraid → Apps → CA User Scripts → Add New Script:

#!/bin/bash
/mnt/.../atm10-auto-update.sh


Schedule z. B. täglich 04:30. Logs im Plugin prüfen.

Pfad-/Beispiel für dieses Setup

SERVER_DIR:
/mnt/user/exclusivegameserver/Exclusive-GameServer/crafty-4/servers/19904793-fdf5-4fd8-8b4b-d37b47ea8771

Crafty URL:
https://yourdockerip:8443

Troubleshooting (Kurz)
Symptom	Ursache	Fix
bash: … bash\r	CRLF-Zeilenenden	In Editor auf UNIX (LF), sonst: sed -i 's/\r$//' script.sh
CurseForge API HTTP 403/401	Falscher Key (z. B. $2a$…), nicht freigeschaltet	Core API Key aus Dev-Console nutzen; Test-curl muss 200 liefern
Kein Server-Pack über API gefunden	Kein Server-Pack publiziert / API down	Später erneut; ggf. Mod-ID prüfen; Script nutzt isServerPack/serverPackFileId
SERVER_DIR nicht gefunden	Pfad falsch	SERVER_DIR korrigieren, mods/ und config/ müssen existieren
Crafty-Aktionen 401/403	Token falsch/abgelaufen	Neuen Crafty-Token erzeugen, im Skript setzen
Nichts passiert / schon aktuell	State greift	rm "$SERVER_DIR/.atm10_last_file_id" für Force-Run
Sicherheit

Keine Keys/Token ins Repo committen. Platzhalter lassen, Werte nur lokal eintragen.

Bei Leaks rotieren: neuen Key/Token erzeugen, alten revoken.

Crafty läuft i. d. R. mit self-signed Cert → Script nutzt -k nur für Crafty, nicht für CurseForge.

Anpassungen

Anderes Modpack? MOD_ID=<projekt_id> setzen (siehe CurseForge Projektseite).

Extra Ordner syncen? Im SYNC-Block erweitern (z. B. schematics/).

Lizenz

MIT – nutze/ändere auf eigenes Risiko. Respektiere stets die CurseForge TOS und die Rechte der Mod-Autoren.

Credits

All The Mods Team (ATM10)

Crafty-4 Maintainer

CurseForge / Overwolf – Core API
