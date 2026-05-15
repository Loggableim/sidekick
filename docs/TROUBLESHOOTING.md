# Sidekick – Fehlerbehebung (Troubleshooting)

> Stand: 2026-05-15 | Version 0.1.0 (MVP 1)
> Sprache: Deutsch | Zielgruppe: Entwickler und Endanwender

---

## Inhalt

1. [Python wurde nicht gefunden](#1-python-wurde-nicht-gefunden)
2. [Port 8787 ist belegt](#2-port-8787-ist-belegt)
3. [WebView2 fehlt](#3-webview2-fehlt)
4. [Hermes startet nicht](#4-hermes-startet-nicht)
5. [App stürzt ab](#5-app-stuerzt-ab)
6. [Keine Logs sichtbar](#6-keine-logs-sichtbar)
7. [Tauri Build schlägt fehl](#7-tauri-build-schlägt-fehl)
8. [vendor/hermes-webui fehlt](#8-vendorhermes-webui-fehlt)
9. [WebUI bleibt leer / weißer Bildschirm](#9-webui-bleibt-leer--weisser-bildschirm)
10. [Settings werden nicht gespeichert](#10-settings-werden-nicht-gespeichert)
11. [Rust/Cargo Fehler](#11-rustcargo-fehler)
12. [Firewall blockiert Hermes WebUI](#12-firewall-blockiert-hermes-webui)
13. [Zeichensatz-Probleme (Umlaute, Sonderzeichen)](#13-zeichensatz-probleme-umlaute-sonderzeichen)
14. [Log-Level und Debugging](#14-log-level-und-debugging)

---

## 1. Python wurde nicht gefunden

### Fehlerbild

```
[FEHLER] Python wurde nicht gefunden.
Python nicht gefunden oder nicht ausführbar: python
```

Oder beim Bootstrap:
```
[FEHLER] Python 3.10+ wurde nicht gefunden!
```

### Ursachen

- Python ist nicht installiert.
- Python ist installiert, aber nicht im PATH.
- Python-Version ist zu alt (< 3.10).

### Lösungen

**1. Python installieren oder aktualisieren**

Lade Python 3.10, 3.11 oder 3.12 herunter:
https://www.python.org/downloads/

**Wichtig:** Bei der Installation den Haken **»Add Python to PATH«** aktivieren.

**2. Installation prüfen**

```powershell
python --version
```

Erwartet: `Python 3.10.x`, `3.11.x` oder `3.12.x`

**3. Python-Pfad manuell setzen**

Falls Python installiert ist, aber nicht im PATH:

```powershell
# Venv-Pfad in der App setzen
# Oder Umgebungsvariable:
$env:Path = "C:\Users\<user>\AppData\Local\Programs\Python\Python312\;$env:Path"
```

In der Sidekick-App: Unter **Einstellungen → Python-Pfad** den Pfad zur `python.exe` eintragen, z.B.:
```
C:\Users\logga\AppData\Local\Programs\Python\Python312\python.exe
```

**4. PowerShell neu starten**

PATH-Änderungen werden nur beim Start von PowerShell wirksam. Nach der Python-Installation ein neues Terminal öffnen.

### Bootstrap-spezifisch

Das Skript `runtime/bootstrap_venv.ps1` sucht Python in folgender Reihenfolge:
1. `py --list` (Python Launcher für Windows)
2. `python --version` (direkter Aufruf)

Falls beides fehlschlägt, liegt entweder keine Installation vor oder der PATH ist falsch.

---

## 2. Port 8787 ist belegt

### Fehlerbild

Sidekick startet Hermes WebUI nicht, oder die Meldung »Port bereits belegt« erscheint.

### Ursachen

- Ein anderer Dienst läuft auf Port 8787 (z.B. eine andere Hermes-Instanz, Docker, lokaler Entwicklungs-Server).
- Sidekick wurde doppelt gestartet.

### Lösungen

**1. Automatischen Port-Fallback nutzen**

Sidekick sucht automatisch einen freien Port (8787 → 8788 → 8789 → aufwärts). Einfach nochmal »Hermes starten« klicken – Sidekick probiert den nächsten Port.

**2. Manuell einen anderen Port setzen**

In der Sidekick-App:
1. Das Port-Feld in den Einstellungen ändern (z.B. `8788`)
2. Auf **»Einstellungen speichern«** klicken
3. Hermes neu starten

Oder per PowerShell:
```powershell
$env:SIDEKICK_PORT = "8788"
.\scripts\dev_start.ps1
```

**3. Prüfen welcher Dienst den Port blockiert**

```powershell
netstat -ano | findstr :8787
```

Die letzte Spalte zeigt die PID. Damit den Prozess identifizieren:

```powershell
tasklist | findstr <PID>
```

**4. Blockierenden Prozess beenden**

```powershell
# Sanft beenden (falls bekannter Dienst)
taskkill /PID <PID>

# Hart beenden
taskkill /F /PID <PID>
```

**Achtung:** Nicht einfach Prozesse killen, die nicht Sidekick gehören – es könnte ein wichtiger Dienst sein.

---

## 3. WebView2 fehlt

### Fehlerbild

- Die App startet, zeigt aber ein leeres oder weisses Fenster.
- Fehlermeldung: »WebView2 Runtime nicht gefunden«
- Tauri kann das Hauptfenster nicht öffnen.

### Ursachen

- Windows 10 LTSC/Server: WebView2 ist nicht vorinstalliert.
- Seltene Windows 10-Installationen ohne WebView2.
- WebView2 wurde deinstalliert oder blockiert.

### Lösungen

**1. WebView2 Evergreen Runtime installieren**

https://developer.microsoft.com/en-us/microsoft-edge/webview2/

Den **Evergreen Standalone Installer** herunterladen und ausführen. Kein Neustart erforderlich.

**2. Prüfen ob WebView2 installiert ist**

Via Registry:
```
HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}
```

In PowerShell:
```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" -Name "pv" -ErrorAction SilentlyContinue
```

**3. Windows Update durchführen**

Auf Windows 10 (1803+) wird WebView2 automatisch über Edge-Updates installiert. Ein Windows Update kann fehlende Komponenten nachliefern.

**4. Edge-Browser installieren**

Falls Edge nicht installiert ist, installiert Edge auch WebView2:
https://www.microsoft.com/edge

---

## 4. Hermes startet nicht

### Fehlerbild

- Der Status bleibt auf »Starting« oder wechselt zu »Error«.
- Die WebUI lädt nicht im iframe.
- Im Log erscheint eine Fehlermeldung.

### Ursachen

| Ursache | Erkennung |
|---------|-----------|
| Python-Pfad falsch | Log: »Python nicht gefunden« |
| vendor/hermes-webui fehlt | Log: »Fehler beim Starten von Hermes WebUI (server.py)« |
| Port blockiert | Log: »Address already in use« |
| Abhängigkeiten fehlen | Log: »ModuleNotFoundError: No module named 'yaml'« |
| Permission-Probleme | Log: »Access denied« |
| Hermes WebUI-Code-Fehler | Log: Traceback aus server.py |

### Lösungen

**1. Logs prüfen**

In der Sidekick-App auf **»Logs öffnen«** klicken. Dort stehen die letzten Meldungen des Backends.

**2. Hermes WebUI direkt testen**

Damit lässt sich feststellen, ob das Problem bei Hermes WebUI selbst liegt oder bei Sidekick:

```powershell
cd F:\finalbrowser
$env:HERMES_WEBUI_HOST = "127.0.0.1"
$env:HERMES_WEBUI_PORT = "8787"
$env:HERMES_WEBUI_STATE_DIR = "$env:APPDATA\Sidekick\state\hermes-webui"
python vendor/hermes-webui/server.py
```

Funktioniert das? Dann liegt das Problem bei Sidekick (Supervisor, Settings, Pfade).
Funktioniert es nicht? Dann liegt das Problem bei Hermes WebUI oder Python.

**3. Venv neu erstellen**

Falls Python-Abhängigkeiten fehlen:

```powershell
.\runtime\bootstrap_venv.ps1
```

Oder manuell:
```powershell
cd F:\finalbrowser
python -m venv --clear .venv
.venv\Scripts\pip install -r vendor\hermes-webui\requirements.txt
```

**4. Python-Pfad in den Einstellungen prüfen**

In der Sidekick-App: **Einstellungen → Python-Pfad** auf den Venv-Python-Pfad setzen:
```
%APPDATA%\Sidekick\runtime\venv\Scripts\python.exe
```

**5. Berechtigungen prüfen**

- Der Ordner `%APPDATA%\Sidekick\` muss beschreibbar sein.
- Der Ordner `F:\finalbrowser\vendor\hermes-webui\` muss lesbar sein.
- Sidekick braucht keine Admin-Rechte.

---

## 5. App stürzt ab

### Fehlerbild

- Sidekick schliesst sich ohne Vorwarnung.
- Ein Windows-Fehlerdialog erscheint (»Sidekick funktioniert nicht mehr«).
- Das Fenster friert ein und reagiert nicht mehr.

### Ursachen

- Tauri/WebView2-Runtime-Fehler.
- Python-Prozess stürzt ab und reisst die Pipes mit.
- Speichermangel (sehr selten).
- Inkompatible WebView2-Version.

### Lösungen

**1. Logs sichern**

Bevor die App neu gestartet wird, die Logs aus dem Fenster kopieren. Nach einem Neustart sind sie weg.

**2. App im Dev-Modus starten**

Damit sieht man Rust-Fehlermeldungen direkt im Terminal:

```powershell
.\scripts\dev_start.ps1
```

Eventuelle `panic!`-Meldungen oder Rust-Fehler erscheinen im Terminal.

**3. WebView2 aktualisieren**

https://developer.microsoft.com/en-us/microsoft-edge/webview2/

**4. Windows-Ereignisanzeige prüfen**

```powershell
Get-WinEvent -LogName Application | Where-Object { $_.Message -like "*Sidekick*" } | Format-List
```

**5. Rust Backtrace aktivieren**

```powershell
$env:RUST_BACKTRACE = "1"
.\scripts\dev_start.ps1
```

Bei einem Rust-Panic erscheint dann ein detaillierter Backtrace im Terminal.

---

## 6. Keine Logs sichtbar

### Fehlerbild

- Das Log-Feld in der Sidekick-App bleibt leer.
- Es erscheinen nur »[DEV]«-Einträge.
- Die Logs aktualisieren sich nicht.

### Ursachen

- Hermes WebUI wurde noch nie gestartet (Logs werden erst geschrieben wenn der Prozess läuft).
- App läuft im Dev-Modus (ohne Tauri) – dann werden Aktionen nur simuliert.
- Der Ringbuffer ist leer.

### Lösungen

**1. Hermes WebUI starten**

Erst wenn Hermes WebUI läuft, werden Logs geschrieben. Auf **»Hermes starten«** klicken.

**2. Tauri-Modus prüfen**

Im Dev-Modus (Öffnen von `app/index.html` direkt im Browser) erscheinen nur simulierte Logs. Echte Logs gibt es nur wenn Sidekick als Tauri-App läuft:

- Entweder via `.\scripts\dev_start.ps1` (startet `cargo tauri dev`)
- Oder via `.\scripts\build_windows.ps1` und Start der `Sidekick.exe`

**3. Logs über die Konsole prüfen**

Falls die App läuft, aber keine Logs im UI erscheinen:

```powershell
# Direkt in der Rust-App:
curl http://127.0.0.1:8787/health
```

Oder Hermes WebUI direkt starten und stdout beobachten (siehe Abschnitt 4).

**4. Ringbuffer-Grenzen verstehen**

- Der Ringbuffer fasst maximal **1000 Einträge**.
- `get_logs()` gibt die **letzten 100 Einträge** zurück.
- Alte Einträge werden überschrieben – wenn viele Logs produziert werden, verschwinden ältere Einträge.

---

## 7. Tauri Build schlägt fehl

### Fehlerbild

```powershell
cargo tauri build --bundles msi
...
[FEHLER] Tauri-Build fehlgeschlagen (Exit-Code: 1)
```

### Ursachen und Lösungen

**Ursache: Rust/Cargo nicht installiert**

```
error: 'cargo' is not recognized as a command
```

Lösung: Rust via https://rustup.rs/ installieren, dann:
```powershell
rustc --version
cargo --version
```

**Ursache: Tauri CLI nicht installiert**

```
error: no such command: `tauri`
```

Lösung:
```powershell
cargo install tauri-cli
```

Oder mit spezifischer Version:
```powershell
cargo install tauri-cli --version "^2"
```

**Ursache: Node.js nicht installiert**

Tauri benötigt Node.js auch ohne Frontend-Build:
```
Error: Unable to find 'node'
```

Lösung: https://nodejs.org/ (Version 18+)

**Ursache: MSVC Build Tools fehlen (Linker-Fehler)**

```
error: linker `link.exe` not found
```

Lösung: **Visual Studio Build Tools** installieren:
1. https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
2. Workload **»Desktop development with C++«** auswählen
3. Installieren

Oder: **Visual Studio Community** (kostenlos) mit gleicher Workload.

**Ursache: WiX Toolset fehlt (nur für MSI-Build)**

```
Error: WiX Toolset v3 not found
```

Lösung (nur nötig für `--bundles msi`):
```powershell
winget install WiXToolset.WiXToolset
# Oder manuell: https://github.com/wixtoolset/wix3/releases
```

Ohne WiX kann mit `cargo tauri build` (ohne `--bundles msi`) gebaut werden – es wird nur eine `.exe` erstellt.

**Ursache: Cargo-Crate-Konflikte**

```
error[E0432]: unresolved import `tauri::...`
```

Lösung:
```powershell
cd F:\finalbrowser\src-tauri
cargo update
cargo build
```

**Ursache: Tauri-Config-Fehler**

```
Error: invalid tauri.conf.json
```

Lösung: `src-tauri/tauri.conf.json` auf Syntax-Fehler prüfen. Das Schema ist unter
https://raw.githubusercontent.com/tauri-apps/tauri/dev/crates/tauri-config-schema/schema.json dokumentiert.

**Ursache: target-Verzeichnis korrupt**

```powershell
cd F:\finalbrowser\src-tauri
cargo clean
cargo build
```

---

## 8. vendor/hermes-webui fehlt

### Fehlerbild

```
[FEHLER] Fehler beim Starten von Hermes WebUI (server.py)
vendor/hermes-webui/server.py: No such file or directory
```

Oder das Verzeichnis `vendor/hermes-webui/` existiert nicht oder ist leer.

### Ursachen

- Das Repository wurde ohne Git-Submodule geklont.
- Das Verzeichnis wurde versehentlich gelöscht.
- Der Pfad in den Einstellungen zeigt auf ein falsches Verzeichnis.

### Lösungen

**1. Prüfen ob das Verzeichnis existiert**

```powershell
ls F:\finalbrowser\vendor\hermes-webui\
```

Sollte `server.py`, `api/`, `static/` usw. enthalten.

**2. Git-Submodul initialisieren (falls per Git geklont)**

```powershell
cd F:\finalbrowser
git submodule update --init --recursive
```

**3. Manuell klonen (falls kein Git-Submodul)**

```powershell
cd F:\finalbrowser
git clone https://github.com/nesquena/hermes-webui.git vendor/hermes-webui
```

**4. Pfad in den Einstellungen korrigieren**

In der Sidekick-App unter **Einstellungen → Hermes-Pfad** den korrekten Pfad setzen:
```
F:\finalbrowser\vendor\hermes-webui
```

Oder per Settings-Datei:
`%APPDATA%\Sidekick\config\settings.json` → Feld `hermes_path`

---

## 9. WebUI bleibt leer / weisser Bildschirm

### Fehlerbild

- Hermes WebUI-Status im iframe ist »Nicht geladen« oder »Fehler«.
- Der iframe zeigt einen weissen Bildschirm.
- Die Sidekick-Control-UI funktioniert, aber die WebUI-Seite ist nicht sichtbar.

### Ursachen

- Hermes WebUI läuft nicht (Status nicht »running«).
- Der Port im iframe stimmt nicht mit dem tatsächlichen Port überein.
- CSP (Content Security Policy) blockiert den iframe.
- Hermes WebUI benötigt länger als erwartet zum Starten.

### Lösungen

**1. Status prüfen**

In der Sidekick-App: Der Status-Badge muss **»Backend läuft«** anzeigen. Wenn nicht, Hermes starten.

**2. WebUI direkt im Browser öffnen**

http://127.0.0.1:8787/ (oder den tatsächlichen Port)

- Funktioniert es im Browser? → Problem liegt am iframe (CSP).
- Funktioniert es nicht im Browser? → Problem liegt am Backend.

**3. Port-Konsistenz prüfen**

- Welcher Port wurde beim Start verwendet? (Siehe Logs: »Hermes WebUI gestartet auf Port X«)
- Ist der Port in den Einstellungen korrekt? (Port-Feld in der Sidekick-App)
- Stimmt der Port im iframe mit dem tatsächlichen überein?

**4. CSP-Einschränkungen prüfen**

Falls der iframe leer bleibt, aber die WebUI im Browser funktioniert, könnte CSP das Problem sein. In der `tauri.conf.json` ist CSP auf `null` gesetzt (keine Einschränkung). Falls das geändert wurde, folgenden Wert setzen:

```json
"security": {
  "csp": null
}
```

**5. Ladezeit abwarten**

Hermes WebUI kann beim ersten Start bis zu 25 Sekunden brauchen (Healthcheck-Timeout). Der iframe lädt automatisch sobald der Healthcheck erfolgreich war.

---

## 10. Settings werden nicht gespeichert

### Fehlerbild

- Nach dem Neustart von Sidekick sind die Einstellungen zurückgesetzt.
- Die Meldung »Einstellungen gespeichert« erscheint, aber beim nächsten Start sind sie weg.

### Ursachen

- Die Settings-Datei ist schreibgeschützt.
- Der `%APPDATA%\Sidekick\config\` Ordner existiert nicht oder ist nicht beschreibbar.
- Berechtigungsprobleme (App läuft ohne ausreichende Rechte).
- Corrupte Settings-Datei (wird dann durch Defaults ersetzt).

### Lösungen

**1. Settings-Datei prüfen**

```powershell
notepad "$env:APPDATA\Sidekick\config\settings.json"
```

Sollte gültiges JSON enthalten. Falls die Datei korrupt ist → löschen (wird beim nächsten Start mit Defaults neu erstellt).

**2. Ordner-Berechtigungen prüfen**

```powershell
icacls "$env:APPDATA\Sidekick\config"
```

Der Benutzer muss Schreibrechte haben. Normalerweise ist das der Fall – `%APPDATA%` ist per Definition beschreibbar.

**3. AppData-Ordner öffnen**

In der Sidekick-App auf **»AppData öffnen«** klicken. Der Explorer öffnet `%APPDATA%\Sidekick\`.

**4. Datei manuell erstellen**

Falls die Settings nicht gespeichert werden, eine leere Datei anlegen:

```powershell
@'
{
  "hermes_path": "F:\\finalbrowser\\vendor\\hermes-webui",
  "python_path": "python",
  "preferred_port": 8787,
  "auto_start": false,
  "auto_restart": false
}
'@ | Out-File -FilePath "$env:APPDATA\Sidekick\config\settings.json" -Encoding utf8
```

---

## 11. Rust/Cargo Fehler

### Fehlerbild

```
error[E0463]: can't find crate for `tauri`
error: failed to run custom build command for `sidekick`
```

### Ursachen

- Cargo kann Crates nicht herunterladen (keine Internetverbindung/Proxy).
- Lock-Datei-Konflikte.
- Rust-Toolchain ist veraltet.
- Cargo-Index korrupt.

### Lösungen

**1. Internetverbindung prüfen**

Cargo lädt beim ersten Build alle Abhängigkeiten herunter. Ohne Internet geht das nicht. Ein Proxy kann ebenfalls Probleme machen.

**2. Cargo-Index zurücksetzen**

```powershell
cd F:\finalbrowser\src-tauri
cargo clean
rm -rf "$env:USERPROFILE\.cargo\registry"
cargo build
```

**3. Rust-Toolchain aktualisieren**

```powershell
rustup update
rustc --version
```

**4. Lock-Datei löschen und neu generieren**

```powershell
cd F:\finalbrowser\src-tauri
rm Cargo.lock
cargo generate-lockfile
```

**5. Proxy-Einstellungen**

Falls ein Proxy verwendet wird:

```powershell
$env:HTTP_PROXY = "http://proxy:8080"
$env:HTTPS_PROXY = "http://proxy:8080"
```

Oder in der `.cargo/config.toml`:
```toml
[http]
proxy = "http://proxy:8080"
```

---

## 12. Firewall blockiert Hermes WebUI

### Fehlerbild

- Hermes WebUI startet, aber die WebUI-Seite bleibt leer.
- Verbindungsfehler im Browser.
- Windows Defender Firewall-Meldung.

### Ursachen

Hermes WebUI bindet auf **127.0.0.1** (localhost). Das sollte normalerweise nicht von der Firewall blockiert werden. Falls doch:

### Lösungen

**1. Python in der Firewall erlauben**

Wenn eine Meldung der Windows Defender Firewall erscheint, **»Zugriff erlauben«** wählen.

**2. Firewall-Regel manuell hinzufügen**

```powershell
New-NetFirewallRule -DisplayName "Sidekick - Hermes WebUI" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 8787-8800 `
  -RemoteAddress 127.0.0.1 `
  -Action Allow
```

**3. Prüfen ob Port lokal erreichbar ist**

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 8787
```

---

## 13. Zeichensatz-Probleme (Umlaute, Sonderzeichen)

### Fehlerbild

- Umlaute (ä, ö, ü) werden in den Logs falsch dargestellt.
- Pfade mit Nicht-ASCII-Zeichen (z.B. `C:\Users\Müller\...`) führen zu Fehlern.

### Ursachen

- PowerShell/OEM-Codepage vs. UTF-8.
- `PYTHONIOENCODING` nicht gesetzt.

### Lösungen

Sidekick setzt automatisch `PYTHONIOENCODING=utf-8` für den Hermes-Prozess. Falls trotzdem Probleme auftreten:

**1. PowerShell-Codepage auf UTF-8 setzen**

```powershell
[Console]::OutputEncoding = [Text.Encoding]::UTF8
```

**2. Python-Codepage prüfen**

```powershell
python -c "import sys; print(sys.getdefaultencoding())"
# Sollte "utf-8" sein
```

**3. Temp-Verzeichnis ohne Umlaute nutzen**

Falls der Benutzerpfad Umlaute enthält und dies zu Problemen führt, kann der `HERMES_WEBUI_STATE_DIR` auf ein Verzeichnis ohne Umlaute umgeleitet werden:

```powershell
$env:HERMES_WEBUI_STATE_DIR = "C:\sidekick-state"
```

---

## 14. Log-Level und Debugging

### Fehler-Logging aktivieren

**Rust Backtrace:**
```powershell
$env:RUST_BACKTRACE = "1"
.\scripts\dev_start.ps1
```

**Tauri Dev-Tools:**
Im Tauri-Dev-Modus können die Dev-Tools mit F12 geöffnet werden (Control UI).

**Hermes WebUI Debug-Modus:**
```powershell
$env:HERMES_WEBUI_DEBUG = "1"
```

**Alle Umgebungsvariablen für Debugging:**

| Variable | Effekt |
|----------|--------|
| `RUST_BACKTRACE=1` | Vollständiger Rust-Backtrace bei Panic |
| `HERMES_WEBUI_DEBUG=1` | Hermes WebUI Debug-Ausgaben |
| `SIDEKICK_PORT=8788` | Abweichenden Port verwenden |
| `HERMES_WEBUI_SKIP_ONBOARDING=1` | Onboarding-Wizard überspringen |

### Wichtige Pfade für Debugging

| Pfad | Inhalt |
|------|--------|
| `%APPDATA%\Sidekick\config\settings.json` | Persistierte Einstellungen |
| `%APPDATA%\Sidekick\state\hermes-webui\` | Hermes-WebUI-Zustand (Sessions, ...) |
| `%APPDATA%\Sidekick\runtime\venv\` | Python-Venv |
| `F:\finalbrowser\vendor\hermes-webui\` | Hermes WebUI Quellcode |
| `F:\finalbrowser\src-tauri\target\release\` | Tauri-Build-Output |

---

## Bei weiteren Problemen

- **GitHub Issues:** https://github.com/Loggableim/sidekick/issues
- **Hermes WebUI Issues:** https://github.com/nesquena/hermes-webui/issues
- **Tauri Hilfe:** https://github.com/tauri-apps/tauri/discussions

Bitte beim Melden eines Fehlers folgende Informationen bereitstellen:

1. Sidekick-Version (aus `README.md` oder `tauri.conf.json`)
2. Windows-Version (`winver`)
3. PowerShell-Version (`$PSVersionTable.PSVersion`)
4. Python-Version (`python --version`)
5. Rust-Version (`rustc --version`)
6. Vollständige Fehlermeldung (aus Logs oder Terminal)
7. Was wurde bereits versucht?
