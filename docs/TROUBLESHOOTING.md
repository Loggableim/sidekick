# Sidekick — Troubleshooting

## Demo-Modus statt echtem IPC
**Symptom:** Logs zeigen `[DEV]` Prefixe, Buttons simulieren nur.

**Ursache:** `app/index.html` wurde direkt im Browser geöffnet (Doppelklick oder `file://`).  
Ohne Tauri-WebView2 ist `window.__TAURI__` nicht verfügbar.

**Lösung:**  
- Führe `scripts/dev_start.ps1` aus (startet Tauri-Fenster mit IPC)  
- Oder starte `src-tauri\target\release\sidekick.exe` (Release-Binary)  
- Der Demo-Modus ist für UI-Tests ohne Backend gedacht — er zeigt klar `[DEV]` und `[DEMO]` Marker.

## Graues Block-Symbol (altes iframe-Problem)
**Symptom:** WebUI-Bereich zeigt ein graues Feld mit Sperr-Symbol.

**Ursache (behoben in MVP 1.2):** Hermes WebUI wurde via `<iframe>` geladen. Dies wurde durch CSP/X-Frame-Options/Cross-Origin blockiert.

**Lösung:**  
- iframe wurde vollständig entfernt.  
- Hermes WebUI öffnet jetzt in einem eigenen nativen Tauri WebviewWindow.  
- Klicke "WebUI öffnen" in der Sidekick Control-Shell.

## Hermes WebUI startet nicht
**Symptom:** Status bleibt "Backend startet…" oder wechselt zu "Fehler".

**Prüfungen:**
1. Python installiert? `python --version`
2. pyyaml installiert? `python -c "import yaml; print(yaml.__version__)"`
3. vendor/hermes-webui vorhanden? `ls vendor/hermes-webui/server.py`
4. Port belegt? `netstat -ano | findstr :8787`
5. Führe `runtime\bootstrap_venv.ps1` aus

## Port-Konflikt
**Symptom:** "Port 8787 is already in use"

**Lösung:** Sidekick hat automatischen Port-Fallback (8787→8788→8789→freier Port).  
Oder manuell: `$env:SIDEKICK_PORT=9000` setzen vor dem Start.

## Logs finden
**AppData-Logs:**  
`%APPDATA%\Sidekick\logs\` — Sidekick-interne Logs.

**Hermes WebUI Logs:**  
Im Log-Panel der Control-Shell sichtbar (Ringbuffer der letzten 200 Zeilen).  
Via "Logs öffnen" Button direkt anspringbar.

Weitere Debugging-Log-Level (in app.js):
- `[STATUS]` — Status-Übergänge und Aktionen
- `[WEBUI]` — WebUI-Fenster-Aktionen
- `[FEHLER]` — Fehler
- `[DEV]` — Demo-Modus Aktionen
- `[POLL]` — Status-Polling

## Release-Binary starten
```powershell
F:\finalbrowser\src-tauri\target\release\sidekick.exe
```
Dann in der Control-Shell: "Hermes starten" klicken.  
Hermes WebUI wird auf Port 8787 gestartet. "WebUI öffnen" klicken für das native Fenster.

## Hermes separat starten (für Tests ohne Sidekick)
```powershell
cd F:\finalbrowser\vendor\hermes-webui
python server.py
# Öffne http://127.0.0.1:8787/health
```

## Build-Fehler
**cargo build --release schlägt fehl:**
- Rust installiert? `rustc --version`
- Tauri CLI installiert? `cargo install tauri-cli`
- WebView2 SDK? Auf Win10/11 vorinstalliert

## App stürzt ab
1. Prüfe Logs im Control-UI Log-Panel
2. Starte Hermes separat (s.o.) — funktioniert das?
3. Prüfe %APPDATA%\Sidekick\config\settings.json auf Korruption
4. Lösche settings.json falls korrupt -> Defaults werden geladen
