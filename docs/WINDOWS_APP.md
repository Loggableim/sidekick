# Sidekick – Windows-App Dokumentation

> Stand: 2026-05-15 | Version 0.1.0 (MVP 1)
> Projekt: F:/finalbrowser | https://github.com/Loggableim/sidekick

---

## 1. Was ist Sidekick?

Sidekick ist eine **native Windows-Desktop-App**, die [Hermes WebUI](https://github.com/nesquena/hermes-webui) in eine eigenständige Anwendung verpackt. Statt Hermes WebUI im Browser zu öffnen, startet Sidekick einen lokalen Python-Server im Hintergrund und zeigt die Oberfläche in einem **WebView2-Fenster** an.

**Das Problem:** Hermes WebUI ist eine reine Web-App – man muss sie über `python server.py` starten und dann im Browser öffnen. Sidekick automatisiert diesen Prozess und bietet eine native Fenster-Hülle mit Start/Stopp/Logs-Steuerung.

**Zielgruppe:** Windows-Anwender, die Hermes WebUI nutzen möchten, ohne sich mit Kommandozeilen-Setup oder Docker auseinandersetzen zu müssen.

**Kernfunktionen (MVP 1):**
- Hermes WebUI automatisch starten/stoppen/neu starten
- Freien Port finden (Fallback 8787 → 8788 → 8789 → …)
- Logs des Backends anzeigen
- Hermes WebUI in einem nativen Fenster anzeigen
- AppData-Verzeichnis zur Ablage von Zustandsdaten
- Einstellungen speichern/laden

---

## 2. Voraussetzungen

| Komponente | Version | Hinweis |
|------------|---------|---------|
| **Windows** | 10 oder 11 | Build 10240+ (Windows 10 RTM) |
| **PowerShell** | 5.1+ | In Windows 10/11 vorinstalliert |
| **Python** | 3.10 – 3.12 | [python.org/downloads](https://www.python.org/downloads/) |
| **WebView2 Runtime** | Evergreen | Siehe unten |
| **Rust** (nur Entwicklung) | nightly | [rustup.rs](https://rustup.rs/) |
| **Git** | beliebig | [git-scm.com](https://git-scm.com/download/win) |

### WebView2 Runtime

WebView2 ist die Browser-Engine, die Sidekick für das Anzeigen der Hermes WebUI-Oberfläche benötigt.

- **Windows 11:** WebView2 ist vorinstalliert.
- **Windows 10 (1803+):** Wird automatisch über Edge-Updates bereitgestellt.
- **Windows 10 LTSC / Server:** Möglicherweise nicht vorhanden.

Fehlt WebView2, laden Sie die **Evergreen Runtime** herunter:
https://developer.microsoft.com/en-us/microsoft-edge/webview2/

Prüfung via Registry (optional):
```
HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}
```

### Python installieren

1. [python.org/downloads](https://www.python.org/downloads/) besuchen
2. Python 3.10, 3.11 oder 3.12 herunterladen (64-Bit empfohlen)
3. **Wichtig:** Bei der Installation den Haken **»Add Python to PATH«** setzen
4. Nach der Installation prüfen:
   ```powershell
   python --version
   ```

---

## 3. Installation / Setup

Sidekick benötigt kein klassisches Installationsprogramm. Das Projekt wird direkt aus dem Quellcode-Verzeichnis gestartet oder gebaut.

### 3.1 Repository klonen

```powershell
cd F:\finalbrowser
git clone https://github.com/Loggableim/sidekick.git
```

### 3.2 Python-Venv einrichten (Bootstrap)

Das Skript `runtime/bootstrap_venv.ps1` übernimmt:

- Prüfung der Systemvoraussetzungen (Windows-Version, PowerShell, Python, WebView2)
- Erstellung eines isolierten Python-Venv unter `%APPDATA%\Sidekick\runtime\venv`
- Installation der benötigten Python-Abhängigkeiten (`pyyaml>=6.0`)

```powershell
cd F:\finalbrowser
.\runtime\bootstrap_venv.ps1
```

**Was passiert im Detail:**

1. **PowerShell-Version prüfen** – 5.1+ erforderlich
2. **Windows-Version prüfen** – 10.0.10240+ erforderlich
3. **WebView2 prüfen** – Registry-Suche (Warnung falls fehlend, kein Abbruch)
4. **Python finden** – via `py --list` (Python Launcher) oder `python` direkt
5. **Venv erstellen** – unter `%APPDATA%\Sidekick\runtime\venv\`
6. **pip installieren** – via `ensurepip` oder fallback `get-pip.py`
7. **Requirements installieren** – `pyyaml>=6.0` aus `vendor/hermes-webui/requirements.txt`
8. **Prüfen** – ob `pyyaml` importierbar ist

### 3.3 Manuelle Venv-Erstellung (falls Bootstrap fehlschlägt)

```powershell
cd F:\finalbrowser
python -m venv .venv
.venv\Scripts\pip install -r vendor\hermes-webui\requirements.txt
```

---

## 4. Entwicklung starten (`dev_start.ps1`)

Das Skript `scripts/dev_start.ps1` startet die vollständige Sidekick-Entwicklungsumgebung.

```powershell
cd F:\finalbrowser
.\scripts\dev_start.ps1
```

**Ablauf:**

| Schritt | Was passiert |
|---------|--------------|
| **1/5** | Voraussetzungen prüfen (Python, Rust, Cargo) |
| **2/5** | Bootstrap ausführen (`runtime/bootstrap_venv.ps1`) |
| **3/5** | Port-Konfiguration (Standard: 8787, via `$env:SIDEKICK_PORT` änderbar) |
| **4/5** | Hermes WebUI im Hintergrund starten (`vendor/hermes-webui/server.py`) |
| **5/5** | Tauri Dev-Modus starten (`cargo tauri dev` in `src-tauri/`) |

**Umgebungsvariablen für dev_start.ps1:**

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `SIDEKICK_PORT` | `8787` | Port für Hermes WebUI |

**Hinweise:**
- Der erste Start lädt Cargo-Crates herunter – das kann **mehrere Minuten** dauern.
- Hermes WebUI ist nach dem Start unter http://127.0.0.1:8787 erreichbar.
- Mit **Strg+C** werden alle Prozesse sauber beendet.

### Manuelles Starten ohne Skript

```powershell
# 1. Hermes WebUI starten (separates Terminal)
cd F:\finalbrowser
$env:HERMES_WEBUI_HOST="127.0.0.1"
$env:HERMES_WEBUI_PORT="8787"
$env:HERMES_WEBUI_STATE_DIR="$env:APPDATA\Sidekick\state\hermes-webui"
python vendor/hermes-webui/server.py

# 2. Tauri Dev starten (zweites Terminal)
cd F:\finalbrowser\src-tauri
cargo tauri dev
```

---

## 5. Release-Build (`build_windows.ps1`)

Das Skript `scripts/build_windows.ps1` erstellt eine ausführbare `.exe` Datei.

```powershell
cd F:\finalbrowser
.\scripts\build_windows.ps1
```

**Ablauf:**

| Schritt | Was passiert |
|---------|--------------|
| **1/5** | Voraussetzungen prüfen (Rust, Cargo, Node.js, Python) |
| **2/5** | Tauri CLI installieren falls nötig (`cargo install tauri-cli`) |
| **3/5** | Release-Build (`cargo tauri build --bundles msi`) |
| **4/5** | Binary + MSI nach `F:/finalbrowser/dist/` kopieren |
| **5/5** | Zusammenfassung anzeigen |

**Ausgabe:**
- `dist/Sidekick.exe` – Die ausführbare Datei
- `dist/Sidekick_*.msi` – Optionaler MSI-Installer (nur mit WiX Toolset)

**Hinweise:**
- Node.js wird für den Tauri-Build benötigt (auch wenn kein Frontend-Build stattfindet).
- Der Build kann beim ersten Mal **lange dauern** (Crate-Downloads + Kompilierung).
- Das MSI wird nur erstellt, wenn WiX Toolset v3 installiert ist (siehe Paketierung).

---

## 6. Paketierung (`package_windows.ps1`)

Das Skript `scripts/package_windows.ps1` erstellt ein verteilbares Paket.

```powershell
cd F:\finalbrowser
.\scripts\package_windows.ps1
```

**Zwei Wege:**

### Weg A: MSI-Installer (empfohlen)

Benötigt **WiX Toolset v3** (nicht v4):
```powershell
winget install WiXToolset.WiXToolset
# oder: https://github.com/wixtoolset/wix3/releases
```

Das Skript erkennt WiX automatisch und erstellt ein MSI via Tauri.

### Weg B: Manuelles Paket (ohne WiX)

Das Skript erstellt ein manuelles Paket in `dist/`:
- `Sidekick.exe` – Die Binary
- `README.md` / `README.txt` – Kurzanleitung

**Einschränkungen:**
- Das Paket ist **nicht code-signiert** – Windows Defender/SmartScreen zeigt eine Warnung.
- Für echte Distribution ist ein **Code-Signing-Zertifikat** nötig.
- Der MSI-Pfad benötigt WiX Toolset v3 (nicht v4).

---

## 7. Konfiguration

### 7.1 Umgebungsvariablen

Vom Supervisor (Tauri-Backend) gesetzte Variablen:

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `HERMES_WEBUI_HOST` | `127.0.0.1` | Loopback-Adresse (nicht von außen erreichbar) |
| `HERMES_WEBUI_PORT` | `8787` (dynamisch) | Tatsächlicher Port via Port-Fallback |
| `HERMES_WEBUI_STATE_DIR` | `%APPDATA%\Sidekick\state\hermes-webui` | Sessions, Workspaces, Settings |
| `PYTHONIOENCODING` | `utf-8` | UTF-8 für stdio |
| `HERMES_WEBUI_PASSWORD` | (leer) | Optionales Passwort für API-Zugriff |

Vom WebUI-Server gelesene Variablen:

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `HERMES_WEBUI_AGENT_DIR` | auto-discover | Expliziter Pfad zum Hermes-Agent |
| `HERMES_HOME` | `~/.hermes` | Basis-Verzeichnis für Hermes-Zustand |
| `HERMES_CONFIG_PATH` | `~/.hermes/config.yaml` | Pfad zur Hermes-Config |
| `HERMES_WEBUI_DEFAULT_MODEL` | (leer) | Standard-Modell-Override |
| `HERMES_WEBUI_SKIP_ONBOARDING` | (leer) | Überspringt den Onboarding-Wizard (`1`) |

### 7.2 Settings-Datei

Persistiert in `%APPDATA%\Sidekick\config\settings.json`:

```json
{
  "hermes_path": "F:\\finalbrowser\\vendor\\hermes-webui",
  "python_path": "F:\\finalbrowser\\runtime\\.venv\\Scripts\\python.exe",
  "preferred_port": 8787,
  "auto_start": false,
  "auto_restart": false
}
```

| Feld | Beschreibung |
|------|-------------|
| `hermes_path` | Pfad zum `vendor/hermes-webui`-Verzeichnis |
| `python_path` | Python-Interpreter (absoluter Pfad oder Name) |
| `preferred_port` | Bevorzugter Port (8787), Fallback automatisch |
| `auto_start` | Hermes automatisch beim App-Start starten |
| `auto_restart` | Hermes bei Absturz automatisch neu starten |

### 7.3 AppData-Verzeichnisse

| Verzeichnis | Funktion |
|-------------|----------|
| `%APPDATA%\Sidekick\` | Basis-Verzeichnis |
| `%APPDATA%\Sidekick\config\` | Settings (JSON) |
| `%APPDATA%\Sidekick\state\` | Allgemeiner App-State |
| `%APPDATA%\Sidekick\state\hermes-webui\` | Sessions, Workspaces, Settings |
| `%APPDATA%\Sidekick\logs\` | App-Logs |
| `%APPDATA%\Sidekick\runtime\` | Python-Venv, Bootstrap-Scripts |

---

## 8. Fehlerbehandlung (Troubleshooting)

### »Python wurde nicht gefunden«

- Python 3.10+ installieren: https://www.python.org/downloads/
- Bei der Installation »Add Python to PATH« aktivieren
- Nachinstallation prüfen: `python --version`
- Evtl. PowerShell neu starten (PATH wird nur beim Start geladen)

### »Port 8787 ist belegt«

Sidekick sucht automatisch einen freien Port (8787 → 8788 → 8789 → …). Falls der Port manuell gesetzt werden soll:

```powershell
$env:SIDEKICK_PORT = "8788"
.\scripts\dev_start.ps1
```

Oder in der App: Port-Feld in den Einstellungen ändern und speichern.

### »WebView2 fehlt«

- Windows 11: WebView2 sollte vorhanden sein.
- Windows 10: Evergreen Runtime installieren:
  https://developer.microsoft.com/en-us/microsoft-edge/webview2/
- Prüfung via Registry:
  `HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}`

### »Hermes startet nicht«

1. Logs in der App prüfen (Button »Logs öffnen«)
2. Hermes WebUI direkt testen:
   ```powershell
   cd F:\finalbrowser
   python vendor/hermes-webui/server.py
   ```
3. Prüfen ob Port bereits belegt ist: `netstat -ano | findstr :8787`
4. Venw neu erstellen: `.\runtime\bootstrap_venv.ps1`

### »App stürzt ab«

- Logs aus `%APPDATA%\Sidekick\logs\` prüfen
- Tauri-Dev-Konsole öffnen (F12 in der Control-UI)
- Rust-Fehlermeldungen im Terminal prüfen (beim Start über `dev_start.ps1`)
- Issue auf GitHub melden: https://github.com/Loggableim/sidekick/issues

### »Keine Logs sichtbar«

- Der Ringbuffer fasst maximal 1000 Einträge, `get_logs()` gibt die letzten 100 zurück.
- Logs werden nur angezeigt, wenn Hermes WebUI gestartet wurde.
- Im Dev-Modus (ohne Tauri) werden Aktionen nur simuliert – echte Logs erscheinen erst in der Tauri-App.

### »Tauri Build schlägt fehl«

Häufige Ursachen:
- **Rust nicht installiert:** `rustup.rs` ausführen
- **Cargo-Crates fehlen:** `cd src-tauri && cargo build` testen
- **Tauri CLI nicht installiert:** `cargo install tauri-cli`
- **Node.js fehlt:** https://nodejs.org/ (Version 18+)
- **MSVC Build Tools:** Bei »linker not found« – `Visual Studio Build Tools` mit »Desktop development with C++« installieren
- **WiX Toolset fehlt** (nur für MSI): Wird für `cargo tauri build --bundles msi` benötigt

### »vendor/hermes-webui fehlt«

Das Verzeichnis `vendor/hermes-webui/` muss existieren. Es enthält den Upstream-Code von Hermes WebUI.

```powershell
cd F:\finalbrowser
ls vendor\hermes-webui\
```

Sollte das Verzeichnis leer sein oder fehlen:
- Git-Submodul initialisieren: `git submodule update --init --recursive`
- Oder manuell klonen: `git clone https://github.com/nesquena/hermes-webui.git vendor/hermes-webui`

---

## 9. Bekannte Grenzen (MVP 1)

Der aktuelle MVP 1 Fokus liegt auf einer **stabilen und einfachen Native-Hülle**. Folgende Funktionen sind **noch nicht implementiert**:

| Feature | Status | Geplant für |
|---------|--------|-------------|
| Tray-Icon (Hintergrund laufen) | ❌ Fehlt | MVP 2 |
| Auto-Start beim Windows-Start | ❌ Fehlt | MVP 2 |
| Auto-Restart bei Absturz | ❌ Fehlt | MVP 2 |
| Settings-Seite (vollständig) | ⚠️ Teilweise | MVP 2 |
| In-Browser öffnen | ⚠️ Grundfunktion | MVP 2 |
| AppData-Ordner im Explorer öffnen | ✅ Vorhanden | – |
| Session-Reset | ❌ Fehlt | MVP 2 |
| Watchdog für Prozess-Überwachung | ❌ Fehlt | MVP 2 |
| Code-Signing (Authenticode) | ❌ Fehlt | MVP 2 |
| Auto-Updater | ❌ Fehlt | MVP 2 |
| MSI-Installer ohne WiX | ❌ Fehlt | MVP 2 |

**Bekannte technische Einschränkungen:**
- Hermes WebUI wird nur auf **127.0.0.1** (localhost) gebunden – kein Fernzugriff.
- Ohne `HERMES_WEBUI_PASSWORD` ist die API ungeschützt.
- Der Hermes-Agent wird auto-discovered – falls nicht vorhanden, läuft die WebUI ohne Agent-Features.
- Logs können sensible Daten enthalten (Prompts, Responses).
- Kein TLS/HTTPS (nur HTTP auf localhost).

---

## 10. Hermes WebUI als Upstream-Vendor

Sidekick bindet Hermes WebUI als **unveränderte Vendor-Komponente** unter `vendor/hermes-webui/` ein.

**Wichtige Prinzipien:**

- **Keine Code-Änderungen** an `vendor/hermes-webui/` – keine Patches, Forks oder Konfiguration innerhalb des Vendor-Verzeichnisses.
- **Steuerung ausschließlich über Environment-Variablen** – der Supervisor setzt HOST, PORT, STATE_DIR.
- **Upstream-Updates** – wenn Hermes WebUI aktualisiert wird, kann das Vendor-Verzeichnis einfach ersetzt werden.

**Startbefehl (Supervisor):**
```
<python_path> server.py
```
- Working Directory: `vendor/hermes-webui/`
- Python: aus dem Venv-Pfad (default: `python`)
- Stdout/Stderr: werden in einen Ringbuffer (1000 Einträge) geleitet

**Detaillierte Dokumentation zur Integration:**
- `docs/HERMES_INTEGRATION.md` – Technische Details zur Einbindung
- `docs/ENV_REFERENCE.md` – Vollständige Liste aller Umgebungsvariablen

---

## 11. Typischer Workflow

```powershell
# 1. Projekt klonen
cd F:\finalbrowser
git clone https://github.com/Loggableim/sidekick.git
cd sidekick

# 2. Bootstrap (einmalig)
.\runtime\bootstrap_venv.ps1

# 3. Entwicklung starten
.\scripts\dev_start.ps1

# 4. Nach fertiger Entwicklung: Build
.\scripts\build_windows.ps1

# 5. Für Distribution: Paket
.\scripts\package_windows.ps1
```

---

## 12. Verwandte Dokumente

| Datei | Beschreibung |
|-------|--------------|
| `README.md` | Projekt-Überblick (englisch) |
| `docs/ARCHITECTURE.md` | Technische Architektur (Entwickler) |
| `docs/TROUBLESHOOTING.md` | Häufige Probleme und Lösungen |
| `docs/HERMES_INTEGRATION.md` | Integration von Hermes WebUI |
| `docs/ENV_REFERENCE.md` | Vollständige Environment-Variablen-Referenz |
| `scripts/README_SCRIPTS.md` | Skript-Dokumentation |
