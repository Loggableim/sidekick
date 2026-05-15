# Sidekick – Architektur

> Stand: 2026-05-15 | Version 0.1.0 (MVP 1)
> Sprache: Deutsch | Zielgruppe: Entwickler

---

## 1. Überblick

Sidekick ist eine **native Windows-Desktop-App**, die Hermes WebUI (Python) als Sidecar-Prozess startet, überwacht und in einem WebView2-Fenster anzeigt. Die App besteht aus drei Hauptkomponenten:

| Komponente | Technologie | Aufgabe |
|------------|-------------|---------|
| **Control UI** | HTML/CSS/JS (WebView2) | Start/Stopp, Logs, Einstellungen |
| **Tauri Backend** | Rust (Tauri 2) | Supervisor, Port-Management, Healthcheck, Settings |
| **Hermes WebUI** | Python (server.py) | KI-Assistent-Oberfläche (Sidecar) |

**Projekt-Struktur:**

```
F:/finalbrowser/
├── src-tauri/              # Tauri 2 Rust-App
│   ├── src/
│   │   ├── main.rs         # App-Einstieg + Tauri-Commands
│   │   ├── supervisor.rs   # Hermes-Child-Prozess-Manager
│   │   ├── ports.rs        # Port-Auswahl/Fallback
│   │   ├── health.rs       # Healthcheck-Polling (HTTP)
│   │   ├── settings.rs     # Settings-Persistenz + AppData-Pfade
│   │   └── lib.rs          # Library-Crate-Exports
│   ├── Cargo.toml
│   └── tauri.conf.json     # Tauri-Konfiguration
├── app/                    # Control-UI
│   ├── index.html
│   ├── app.js
│   └── styles.css
├── vendor/
│   └── hermes-webui/       # Upstream-Vendor (read-only)
│       ├── server.py       # Python-Server
│       ├── api/            # API-Endpunkte
│       ├── static/         # Frontend-Assets
│       └── requirements.txt # pyyaml>=6.0
├── runtime/
│   ├── bootstrap_venv.ps1  # Venv-Erstellung + Dependency-Installation
│   └── requirements.lock.txt
├── scripts/
│   ├── dev_start.ps1       # Entwicklungsstart
│   ├── build_windows.ps1   # Release-Build
│   └── package_windows.ps1 # Paketierung
└── docs/                   # Dokumentation
```

---

## 2. Architektur-Diagramm

```
┌──────────────────────────────────────────────────────────────────────┐
│                   Sidekick (Tauri 2 Desktop-App)                      │
│                                                                       │
│  ┌──────────────────────────────────┐   ┌──────────────────────────┐  │
│  │        Control UI (WebView2)      │   │   Hermes WebUI-Fenster   │  │
│  │   ┌────────────────────────────┐  │   │   ┌──────────────────┐  │  │
│  │   │  Start/Stop/Neustart       │  │   │   │  Hermes WebUI    │  │  │
│  │   │  Logs (Ringbuffer)         │  │   │   │  (iframe,        │  │  │
│  │   │  Status-Anzeige            │  │   │   │   http://127.0.0.1│  │  │
│  │   │  Port/Pfad-Einstellungen   │  │   │   │   :{port}/)       │  │  │
│  │   └───────────┬────────────────┘  │   │   └──────────────────┘  │  │
│  └───────────────┼──────────────────┘   └───────────┼──────────────┘  │
│                  │ IPC (Tauri invoke)                │ Browser-GET     │
│                  ▼                                   │                 │
│  ┌───────────────────────────────────────────────────┴──────────┐    │
│  │                    Tauri Backend (Rust)                       │    │
│  │                                                               │    │
│  │  ┌─────────────┐  ┌──────────┐  ┌───────────┐  ┌─────────┐  │    │
│  │  │  Supervisor  │  │   Ports  │  │   Health  │  │ Settings│  │    │
│  │  │  (Prozess-   │  │  (Port-  │  │  (HTTP-   │  │ (JSON-  │  │    │
│  │  │   Lifecycle) │  │  Fallback│  │  Polling) │  │  Store) │  │    │
│  │  └───────┬──────┘  └──────────┘  └───────────┘  └─────────┘  │    │
│  └──────────┼────────────────────────────────────────────────────┘    │
│             │ Child-Prozess (stdout/stderr via Pipes)                 │
│             ▼                                                        │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │              Hermes WebUI (Python Sidecar)                     │    │
│  │                                                               │    │
│  │  server.py → api/config.py → api/routes.py → ...             │    │
│  │                                                               │    │
│  │  - Liest Config aus Umgebungsvariablen (HOST, PORT, STATE)   │    │
│  │  - Baut einen HTTP-Server auf (127.0.0.1:{port})             │    │
│  │  - Bietet API-Endpunkte: /health, /api/...                   │    │
│  │  - Serviert static/ Frontend-Assets                          │    │
│  │                                                               │    │
│  │  Abhängigkeiten: nur pyyaml>=6.0                             │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Datenfluss

### 3.1 App-Start

```
1. Nutzer startet Sidekick.exe
2. Tauri öffnet WebView2-Fenster mit app/index.html (Control UI)
3. Control UI lädt Settings aus %APPDATA%\Sidekick\config\settings.json
4. Status-Polling startet (alle 2s, Tauri-IPC)
5. Nutzer klickt »Hermes starten«
   ↓
6. invoke('start_hermes')
   ↓
7. supervisor::start_hermes()
   ├── ports::find_free_port(8787)  → Port X
   ├── Command::new(python_path)
   │   ├── .arg("server.py")
   │   ├── .env("HERMES_WEBUI_HOST", "127.0.0.1")
   │   ├── .env("HERMES_WEBUI_PORT", X)
   │   ├── .env("HERMES_WEBUI_STATE_DIR", ...)
   │   ├── .current_dir(vendor/hermes-webui)
   │   └── .stdout(Stdio::piped())
   ├── spawn() → Child-Prozess
   ├── Reader-Threads für stdout/stderr starten
   └── Status → "running"
   ↓
8. health::check_health(port, 25s)  → Polling alle 500ms
   ↓
9. Control UI erhält Status "running"
   ↓
10. iframe.src = "http://127.0.0.1:{port}/" → Hermes WebUI wird geladen
```

### 3.2 Log-Erfassung

```
Python-Prozess (stdout)
    │  [out] Hermes Web UI listening on http://127.0.0.1:8787
    │  [out] {"ts":"...","method":"GET","path":"/health","status":200}
    ▼
Reader-Thread (BufReader)
    │  append_log("[out] ...")
    ▼
Ringbuffer (Arc<Mutex<Vec<String>>), max 1000 Einträge)
    │
    ▼ (bei Aufruf get_logs())
Control UI (letzte 100 Einträge)
```

### 3.3 App-Stopp

```
1. Nutzer klickt »Hermes stoppen«
   ↓
2. invoke('stop_hermes')
   ↓
3. supervisor::stop_hermes()
   ├── taskkill /PID <pid>          (sanft, sendet Ctrl+C)
   ├── Polling auf exit (max 3s)
   │   ├── Erfolg → child.wait()    (Ressourcen freigeben)
   │   └── Timeout → taskkill /F /PID <pid>  (hart, inkl. Prozessbaum)
   └── Status → "stopped"
   ↓
4. iframe.src = "" → WebUI entladen
```

---

## 4. Entscheidungen (Architecture Decision Records)

### 4.1 Warum Tauri (und nicht Electron)?

| Kriterium | Tauri 2 | Electron |
|-----------|---------|----------|
| **Binary-Größe** | ~5-10 MB | ~150-250 MB |
| **RAM-Nutzung** | ~50-100 MB | ~200-500 MB |
| **WebView** | System-eigen (WebView2) | Gebündeltes Chromium |
| **Sprache** | Rust (sicher, schnell) | JavaScript/C++ |
| **Windows-Kompatibilität** | WebView2 vorinstalliert (Win 11/10) | Eigenes Chromium – immer kompatibel |
| **Update-Mechanismus** | Manuell (MVP 1) | Built-in (Electron Updater) |

**Entscheidung:** Tauri 2, weil:
- Deutlich kleinere Binaries, niedrigerer Speicherverbrauch
- Rust bietet Sicherheit und Performance für den Supervisor
- WebView2 ist auf aktuellen Windows-Systemen vorinstalliert
- Kein gebündeltes Chromium nötig

### 4.2 Warum Python Sidecar (und nicht Rust-Neuschreibung)?

- Hermes WebUI ist ein **ausgereiftes Python-Projekt** mit umfangreichen API-Endpunkten, Datenbank-Logik und Integrationen.
- Eine Neuschreibung in Rust würde Monate dauern und keinen Mehrwert für MVP 1 bieten.
- Der Sidecar-Ansatz (Python-Prozess + Rust-Supervisor) ist **erprobt, trennbar und wartbar**.
- Bei Bedarf können einzelne Komponenten später nach Rust portiert werden.

### 4.3 Warum kein Docker?

- Docker ist auf Windows nicht Standard, erfordert WSL 2 oder Hyper-V.
- Zielgruppe sind normale Windows-Anwender – Docker ist eine zusätzliche Hürde.
- Hermes WebUI hat nur **eine einzige Python-Abhängigkeit** (`pyyaml`) – ein Docker-Container wäre Overkill.
- Ein Python-Venv ist einfacher, schneller und ressourcenschonender.

### 4.4 Warum Control UI + WebUI (zwei WebView2-Fenster/iframes)?

- **Trennung von Steuerung und Inhalt:** Die Control UI (Start/Stopp/Logs) ist getrennt von der Hermes-WebUI-Oberfläche.
- Die Control UI wird über **Tauri-IPC** (invoke) gesteuert, nicht über HTTP.
- Hermes WebUI wird als **iframe** eingebettet – das ist die einfachste Möglichkeit, eine bestehende Web-App in eine native Hülle zu packen.
- Der iframe-Ansatz erlaubt es, Hermes WebUI **unverändert** zu lassen (kein Fork/keine Patches).

---

## 5. Sicherheit

| Maßnahme | Beschreibung |
|----------|-------------|
| **localhost-only** | Hermes WebUI bindet auf `127.0.0.1` (Loopback) – kein Zugriff von außen |
| **Optionaler Passwortschutz** | `HERMES_WEBUI_PASSWORD` schützt alle API-Endpunkte |
| **Kein Docker/WSL** | Keine zusätzlichen Angriffsflächen durch Container |
| **Prozess-Isolation** | Python-Sidecar läuft mit Benutzerrechten (kein Admin erforderlich) |
| **Defensive Kill-Strategie** | Sauberes Prozess-Kill ohne Zombies |
| **Keine Shell-Injection** | Rust's `Command::new` verwendet Listen-Form (kein `shell=True`) |

**Hinweis:** Ohne Passwort ist die Hermes-WebUI-API für jedes lokale Programm zugänglich. Für sensible Umgebungen ist ein Passwort zu empfehlen.

---

## 6. AppData-Pfade

Alle Applikationsdaten liegen unter `%APPDATA%\Sidekick\` (standard Windows-Konvention).

```
%APPDATA%\Sidekick\                   # Basis (C:\Users\<user>\AppData\Roaming\Sidekick\)
├── config\
│   └── settings.json                 # Persistente Einstellungen
├── state\
│   └── hermes-webui\                 # HERMES_WEBUI_STATE_DIR
│       ├── sessions/                 # Session-Datenbank
│       ├── settings.json             # WebUI-Einstellungen
│       └── workspaces.json           # Workspace-Konfiguration
├── logs\                             # App-Logs (zukünftig)
└── runtime\
    └── venv\                         # Python-Venv (via bootstrap_venv.ps1)
        ├── Scripts\python.exe
        ├── Scripts\pip.exe
        └── Lib\site-packages\...
```

**Zugriff in Rust (settings.rs):**
```rust
fn appdata_dir() -> PathBuf {
    PathBuf::from(env!("APPDATA")).join("Sidekick")
}
// → C:\Users\logga\AppData\Roaming\Sidekick
```

---

## 7. Port-Fallback

Definiert in `src-tauri/src/ports.rs`:

```
1. 8787  → Sofortversuch (bevorzugter Port)
2. 8788  → Fallback 1
3. 8789  → Fallback 2
4. 8790+ → Linearer Scan aufwärts
5. 0     → Letzte Ressource: OS wählt freien ephemeren Port
```

```rust
pub fn find_free_port(preferred: u16) -> u16;
```

- Alle Probes binden auf `127.0.0.1`.
- Die Funktion gibt **immer einen gültigen Port zurück**.
- Ein Panic tritt nur bei extrem unwahrscheinlichen OS-Fehlern auf (keine freien Ports auf Loopback).

---

## 8. Healthcheck

Definiert in `src-tauri/src/health.rs`.

```
GET http://127.0.0.1:{port}/health

Erfolg (200): { "status": "ok", ... }
Degraded (503): { "status": "degraded", ... }
Timeout: HealthStatus::Starting
Fehler: HealthStatus::Error(msg)
```

- **Polling-Intervall:** 500 ms
- **Default-Timeout:** 25 Sekunden (~50 Polls)
- **Client:** `reqwest::blocking::Client`
- **Thread:** Blockierend (im Tauri-Command-Kontext)

---

## 9. Supervisor (Prozess-Lifecycle)

Definiert in `src-tauri/src/supervisor.rs`.

### Zustandsmaschine

```
         ┌──────────┐
         │  STOPPED │ ←── Initialzustand
         └─────┬────┘
               │ start_hermes()
               ▼
         ┌──────────┐
         │ STARTING │ ←── Command::spawn() wurde aufgerufen
         └─────┬────┘
               │ spawn() erfolgreich
               ▼
         ┌──────────┐
         │  RUNNING │ ←── Child läuft, Reader-Threads aktiv
         └─────┬────┘
               │ stop_hermes()
               ▼
         ┌──────────┐
         │  STOPPED │ ←── Prozess beendet
         └──────────┘

Fehlerpfad:
STARTING ──→ ERROR (Python nicht gefunden / Spawn fehlgeschlagen)
```

### Status-Werte

| Status | Bedeutung |
|--------|-----------|
| `stopped` | Kein Prozess läuft (Initialzustand) |
| `starting` | `Command::spawn` wurde aufgerufen |
| `running` | Prozess läuft |
| `error` | Python nicht gefunden oder Spawn fehlgeschlagen |

### Kill-Strategie (Windows)

```
1. Graceful:  taskkill /PID <pid>       (sendet Ctrl+C)
2. Wait:      Polling auf exit, max 3s
3. Force:     taskkill /F /PID <pid>    (Kill inkl. Prozessbaum)
4. Finalize:  child.wait()              (Ressourcen freigeben)
```

### Thread-Safety

- Supervisor-Struct wird von `Mutex<HermesSupervisor>` geschützt.
- Logs haben einen **eigenen** `Arc<Mutex<Vec<String>>>` – Reader-Threads und API blockieren sich nicht gegenseitig.
- Singleton via `OnceLock` (kein externes Crate nötig).

---

## 10. Settings-Persistenz

Definiert in `src-tauri/src/settings.rs`.

```json
{
  "hermes_path": "F:\\finalbrowser\\vendor\\hermes-webui",
  "python_path": "F:\\finalbrowser\\runtime\\.venv\\Scripts\\python.exe",
  "preferred_port": 8787,
  "auto_start": false,
  "auto_restart": false
}
```

- **Format:** JSON
- **Speicherort:** `%APPDATA%\Sidekick\config\settings.json`
- **Default-Werte:** Fallback auf sinnvolle Standardwerte
- **Fehlerbehandlung:** Bei korrupter Datei → stille Rückkehr zu Defaults

---

## 11. Tauri-Commands (IPC-Schnittstelle)

Die Control UI kommuniziert über Tauri IPC (`window.__TAURI__.invoke`) mit dem Rust-Backend.

| Command | Funktion | Rückgabe |
|---------|----------|----------|
| `start_hermes` | Hermes-Prozess starten | `Result<String, String>` |
| `stop_hermes` | Hermes-Prozess stoppen | `Result<String, String>` |
| `restart_hermes` | Hermes-Prozess neustarten | `Result<String, String>` |
| `get_status` | Aktuellen Status abfragen | `String` ("stopped", ...) |
| `get_logs` | Letzte Logzeilen abrufen | `Result<Vec<String>, String>` |
| `open_appdata` | AppData-Ordner im Explorer öffnen | `Result<(), String>` |
| `open_browser` | Hermes WebUI im Browser öffnen | `Result<(), String>` |
| `get_settings` | Einstellungen laden | `Settings` |
| `save_settings` | Einstellungen speichern | `Result<(), String>` |

---

## 12. Wichtige Abhängigkeiten

### Rust (Cargo.toml)

| Crate | Version | Verwendung |
|-------|---------|------------|
| `tauri` | 2 | Desktop-App-Framework |
| `serde` | 1 (derive) | JSON-Serialisierung (Settings) |
| `serde_json` | 1 | JSON-Parsing |
| `reqwest` | 0.12 (blocking) | HTTP-Client für Healthcheck |

### Python (requirements.txt)

| Paket | Version |
|-------|---------|
| `pyyaml` | >= 6.0 |

---

## 13. Vendor-Strategie

- Hermes WebUI liegt unter `vendor/hermes-webui/` (read-only).
- **Keine** Code-Änderungen im Vendor-Verzeichnis.
- Steuerung ausschließlich über **Environment-Variablen**.
- Bei Upstream-Updates kann das Vendor-Verzeichnis ausgetauscht werden – solange die Env-Var-Schnittstelle stabil bleibt, sind keine Sidekick-Änderungen nötig.
- Siehe `docs/HERMES_INTEGRATION.md` für Details.

---

## 14. Verwandte Dokumente

| Datei | Beschreibung |
|-------|--------------|
| `README.md` | Projekt-Überblick |
| `docs/WINDOWS_APP.md` | Windows-App-Dokumentation (Anwender) |
| `docs/TROUBLESHOOTING.md` | Häufige Probleme und Lösungen |
| `docs/HERMES_INTEGRATION.md` | Hermes-WebUI-Integration (technisch) |
| `docs/ENV_REFERENCE.md` | Vollständige Environment-Variablen-Referenz |
| `docs/WINDOWS_STARTUP_STRATEGY.md` | Windows-Startstrategie (Planung) |
| `scripts/README_SCRIPTS.md` | Skript-Dokumentation |
