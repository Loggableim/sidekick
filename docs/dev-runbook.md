# Sidekick — Dev Runbook

## Voraussetzungen
- Windows 10 oder 11
- Python 3.10+ (in PATH, inkl. pip)
- Rust + Cargo (via https://rustup.rs/)
- WebView2 Runtime (auf Win11 vorinstalliert)

## Schnellstart

### 1. Hermes WebUI separat testen
```powershell
cd F:\finalbrowser\vendor\hermes-webui
python server.py
# Öffne http://127.0.0.1:8787/health → {"status":"ok"}
```

### 2. Sidekick Dev starten (mit Tauri-Fenster)
```powershell
cd F:\finalbrowser
.\scripts\dev_start.ps1
```
Das Skript:
- Prüft Python/Rust/Cargo
- Führt bootstrap_venv.ps1 aus (venv + pyyaml)
- Startet Hermes WebUI auf Port 8787
- Startet Frontend-HTTP-Server auf Port 1420
- Startet `cargo tauri dev` (öffnet natives Fenster)

### 3. Release-Binary bauen
```powershell
cd F:\finalbrowser
.\scripts\build_windows.ps1
```
Binary: `F:\finalbrowser\src-tauri\target\release\sidekick.exe`

### 4. Manueller Dev-Start (wenn dev_start.ps1 nicht passt)
```powershell
# Terminal 1: Hermes WebUI
cd F:\finalbrowser\vendor\hermes-webui
python server.py

# Terminal 2: Frontend-HTTP-Server
cd F:\finalbrowser\app
python -m http.server 1420

# Terminal 3: Tauri Dev
cd F:\finalbrowser\src-tauri
$env:PATH="$env:USERPROFILE\.cargo\bin;$env:PATH"
cargo tauri dev
```

## Wichtige Pfade
| Pfad | Zweck |
|---|---|
| `F:\finalbrowser\` | Projekt-Root |
| `vendor\hermes-webui\` | Hermes WebUI (Git-Submodule) |
| `src-tauri\` | Tauri/Rust-Projekt |
| `app\` | Control-UI (HTML/JS/CSS) |
| `runtime\` | Python-Runtime (bootstrap, venv) |
| `scripts\` | Dev/Build/Package-Skripte |
| `docs\` | Dokumentation |
| `%APPDATA%\Sidekick\` | AppData (Settings, State, Logs) |

## Commands/IPC
| Command | Funktion | Status |
|---|---|---|
| `start_hermes` | Startet Hermes WebUI | ✅ |
| `stop_hermes` | Stoppt Hermes WebUI | ✅ |
| `restart_hermes` | Startet WebUI neu | ✅ |
| `get_status` | WebUI-Status ("stopped"/"starting"/"running"/"error") | ✅ |
| `get_logs` | Letzte Logzeilen | ✅ |
| `open_appdata` | %APPDATA%\Sidekick im Explorer | ✅ |
| `open_external_browser` | Hermes WebUI im Standard-Browser | ✅ |
| `open_hermes_window` | Hermes WebUI in Tauri-WebviewWindow | ✅ |
| `close_hermes_window` | Schliesst WebviewWindow | ✅ |
| `get_settings` | Lädt Settings aus %APPDATA% | ✅ |
| `save_settings` | Speichert Settings | ✅ |

## Fehlerdiagnose
- **Graues Fenster**: Hermes WebUI wird nicht im iframe geladen. Nutze "WebUI öffnen" Button für eigenes Fenster.
- **Demo-Modus**: app/index.html direkt im Browser geöffnet. Nutze Tauri-Fenster für echten IPC.
- **Port belegt**: Sidekick nutzt Port-Fallback (8787→8788→8789→freier Port).
- **Python nicht gefunden**: Führe `runtime\bootstrap_venv.ps1` aus.
