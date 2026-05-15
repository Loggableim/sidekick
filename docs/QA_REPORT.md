# QA Report — Sidekick (F:/finalbrowser)

> Erstellt: 2026-05-15 | Umfang: Vollständige Projektprüfung
> Basis: Tauri 2 + WebView2 + Hermes WebUI Sidecar

---

## 1. Structure Check

### Erwartete vs. vorhandene Dateien

| Erwartet | Status | Bemerkung |
|----------|--------|-----------|
| `src-tauri/Cargo.toml` | ✅ Vorhanden | Korrekt |
| `src-tauri/tauri.conf.json` | ✅ Vorhanden | Tauri v2 Format |
| `src-tauri/src/main.rs` | ✅ Vorhanden | |
| `src-tauri/src/lib.rs` | ✅ Vorhanden | Nur Kommentar, kein Code |
| `src-tauri/build.rs` | ✅ Vorhanden | Korrekt |
| `src-tauri/src/supervisor.rs` | ✅ Vorhanden | 685 Zeilen |
| `src-tauri/src/ports.rs` | ✅ Vorhanden | 93 Zeilen |
| `src-tauri/src/health.rs` | ✅ Vorhanden | 144 Zeilen |
| `src-tauri/src/settings.rs` | ✅ Vorhanden | 309 Zeilen |
| `app/index.html` | ✅ Vorhanden | |
| `app/styles.css` | ✅ Vorhanden | |
| `app/app.js` | ✅ Vorhanden | |
| `app/hermes-icons.html` | ✅ Vorhanden | |
| `runtime/bootstrap_venv.ps1` | ✅ Vorhanden | |
| `runtime/requirements.lock.txt` | ✅ Vorhanden | |
| `scripts/dev_start.ps1` | ✅ Vorhanden | |
| `scripts/build_windows.ps1` | ✅ Vorhanden | |
| `scripts/package_windows.ps1` | ✅ Vorhanden | |
| `scripts/README_SCRIPTS.md` | ✅ Vorhanden | |
| `docs/HERMES_INTEGRATION.md` | ✅ Vorhanden | |
| `docs/ENV_REFERENCE.md` | ✅ Vorhanden | |
| `docs/WINDOWS_STARTUP_STRATEGY.md` | ✅ Vorhanden | |
| `README.md` | ✅ Vorhanden | |

### In README referenzierte, aber nicht vorhandene Dateien

| Referenziert in README | Erwarteter Pfad | Status |
|------------------------|-----------------|--------|
| `src-tauri/src/logs.rs` | `src-tauri/src/logs.rs` | ❌ Fehlt |
| `docs/WINDOWS_APP.md` | `docs/WINDOWS_APP.md` | ❌ Fehlt |
| `docs/ARCHITECTURE.md` | `docs/ARCHITECTURE.md` | ❌ Fehlt |
| `docs/TROUBLESHOOTING.md` | `docs/TROUBLESHOOTING.md` | ❌ Fehlt |

---

## 2. Rust Code Review

### 2.1 Module-Deklarationen in main.rs

| Modul | Deklariert (`mod`) | Physisch vorhanden | Aufgerufen |
|-------|--------------------|--------------------|------------|
| `supervisor` | ✅ Zeile 5 | ✅ supervisor.rs | ✅ |
| `settings` | ✅ Zeile 6 | ✅ settings.rs | ✅ |
| `ports` | ✅ Zeile 7 | ✅ ports.rs | ✅ |
| `health` | ✅ Zeile 8 | ✅ health.rs | ❌ **Nie aufgerufen** |

**Issue 2.1.1:** `health.rs` wird in main.rs als Modul deklariert (`mod health;`) aber nirgendwo im Code verwendet. Die Funktion `check_health()` ist definiert, wird aber von keinem Tauri-Command oder Supervisor aufgerufen.

### 2.2 Tauri-Commands in main.rs

| Command | Registriert in `generate_handler![]` | Parametermatch |
|---------|--------------------------------------|----------------|
| `start_hermes` | ✅ | — |
| `stop_hermes` | ✅ | — |
| `restart_hermes` | ✅ | — |
| `get_status` | ✅ | — |
| `get_logs` | ✅ | — |
| `open_appdata` | ✅ | — |
| `open_browser(port: u16)` | ✅ | — |
| `get_settings` | ✅ | — |
| `save_settings(settings_data: Settings)` | ✅ | — |

**Issue 2.2.1:** Fehlende Tauri-Commands. `app.js` ruft folgende Commands auf, die in main.rs NICHT registriert sind:
- `open_logs` — existiert nicht
- `open_in_browser` — existiert nicht; der korrekte Command heißt `open_browser(port: u16)`
- `load_settings` — existiert nicht; der korrekte Command heißt `get_settings`

### 2.3 Cargo.toml — Dependencies

| Dependency | Version | Status |
|------------|---------|--------|
| `tauri` | 2.x (unpinned) | ✅ Tauri v2 |
| `serde` | 1.x mit `derive` | ✅ |
| `serde_json` | 1.x | ✅ |
| `reqwest` | 0.12 mit `blocking` | ✅ |
| `tauri-build` | 2.x | ✅ |

Keine Fehler in den Dependencies.

### 2.4 tauri.conf.json — Format (Tauri v2)

| Feld | Wert | Status |
|------|------|--------|
| `$schema` | Tauri v2 Schema URL | ✅ |
| `build.frontendDist` | `../app` | ✅ |
| `build.devUrl` | `http://localhost:1420` | ✅ |
| `app.windows[0]` | title, width, height, resizable | ✅ |
| `bundle.targets` | `"all"` | ⚠️ `"all"` ist kein gültiger Tauri v2 Bundle-Target-String. Erwartet wird ein Array wie `["msi", "nsis"]` oder ein einzelner String. |
| `bundle.icon` | Liste mit `.png`, `.icns`, `.ico` | ✅ |

---

## 3. App-UI Review

### 3.1 app.js — Tauri invoke()-API

| Aufruf | JS-Code | Rust-Command | Match |
|--------|---------|--------------|-------|
| `start_hermes` | `invoke('start_hermes', {})` | ✅ `start_hermes()` | ✅ |
| `stop_hermes` | `invoke('stop_hermes', {})` | ✅ `stop_hermes()` | ✅ |
| `restart_hermes` | `invoke('restart_hermes', {})` | ✅ `restart_hermes()` | ✅ |
| `get_status` | `invoke('get_status', {})` | ✅ `get_status()` | ⚠️ Rückgabetyp: JS erwartet Objekt, Rust liefert String |
| `get_logs` | `invoke('get_logs', {})` | ✅ `get_logs()` | (wird nicht direkt in JS aufgerufen, nur für openLogs) |
| `open_appdata` | `invoke('open_appdata', {})` | ✅ `open_appdata()` | ✅ |
| `load_settings` | `invoke('load_settings', {})` | ❌ Fehlt | **Command heißt `get_settings`** |
| `save_settings` | `invoke('save_settings', { settings: settings })` | ✅ `save_settings(settings_data)` | ⚠️ Parameter-Name mismatch: JS sendet `settings`, Rust erwartet `settings_data` |
| `open_logs` | `invoke('open_logs', {})` | ❌ Fehlt | **Command existiert nicht** |
| `open_in_browser` | `invoke('open_in_browser', { url: url })` | ❌ Fehlt | **Command heißt `open_browser(port: u16)`** |

### 3.2 index.html — Elemente

| Element | ID | Vorhanden |
|---------|----|-----------|
| Status-Badge | `status-badge` | ✅ |
| Error-Display | `error-display`, `error-text`, `error-dismiss` | ✅ |
| Actions | `btn-start`, `btn-stop`, `btn-restart`, `btn-logs`, `btn-appdata`, `btn-browser` | ✅ |
| Settings | `port`, `autostart`, `python-path`, `hermes-path` | ✅ |
| Log-Output | `log-output`, `btn-clear-logs` | ✅ |
| WebView | `webview-frame`, `webview-placeholder`, `webview-status` | ✅ |
| Scripts | `app.js` | ✅ |

**Issue 3.2.1:** `hermes-icons.html` wird in `index.html` nirgendwo via `<link>` oder `<script>` importiert. Die SVG-Icons in den Buttons sind inline definiert, die Icon-Sammlung in `hermes-icons.html` wird nie genutzt.

### 3.3 styles.css — Vollständigkeit

| Bereich | Status |
|---------|--------|
| CSS-Variablen (Dark Theme) | ✅ |
| Reset & Base | ✅ |
| Scrollbar | ✅ |
| Header | ✅ |
| Badge-States (idle, starting, running, error, restarting) | ✅ |
| Error Display | ✅ |
| Main Layout | ✅ |
| Sidebar | ✅ |
| Card | ✅ |
| Action Grid | ✅ |
| Buttons (primary, secondary, danger, outline, sm, icon) | ✅ |
| Settings (input-field, checkbox) | ✅ |
| Content Area | ✅ |
| Log Panel | ✅ |
| WebView Panel | ✅ |
| Responsive (@media max-width 800px) | ✅ |
| Transitions (fade-in, slide-down) | ✅ |

---

## 4. Supervisor Review

### 4.1 Windows-Kompatibilität

| Aspekt | Status | Prüfung |
|--------|--------|---------|
| Kein Unix-only Code (`signal`, `nix` crate) | ✅ | Nur `std::process::Command` und `std::thread` |
| `taskkill` für Prozesssteuerung | ✅ | `try_graceful_kill` und `force_kill_process` |
| `command::current_dir` | ✅ | Wird gesetzt |
| `Stdio::piped()` für stdout/stderr | ✅ | Windows-kompatibel |

### 4.2 Kill-Strategie

| Schritt | Methode | Status |
|---------|---------|--------|
| 1. Sanft | `taskkill /PID <pid>` (ohne /F) | ✅ |
| 2. Warten | `child.try_wait()` Polling (200ms Interval, 3s Timeout) | ✅ |
| 3. Hart | `taskkill /F /PID <pid>` | ✅ |
| 4. Final | `child.wait()` | ✅ |

**Issue 4.2.1:** In `stop_hermes()` wird nach der graceful-Kill-Phase nur `child.wait()` im Force-Fall-Pfad aufgerufen (Zeile 349). Wenn der graceful-Kill erfolgreich ist (`try_graceful_kill` returned `true`), wird **kein** `child.wait()` aufgerufen. Der `Child`-Handle wird gedroppt ohne `wait()`, was zu einem Zombie-Prozess führen kann.

Allerdings: `try_graceful_kill` ruft bereits `child.try_wait()` im Polling-Loop auf, und wenn `Ok(Some(_))` returned wird, wurde der Prozess bereits reaped. In dem Fall ist `child.wait()` nicht mehr nötig, weil `try_wait` ihn schon eingesammelt hat. Das ist korrekt.

### 4.3 Thread-Safety

| Mechanismus | Status |
|-------------|--------|
| `OnceLock<Mutex<HermesSupervisor>>` | ✅ |
| Separater `Arc<Mutex<Vec<String>>>` für Logs | ✅ (verhindert Deadlock) |
| Reader-Threads terminieren bei Pipe-Close | ✅ |
| Kein `unsafe` Code | ✅ |

---

## 5. Settings Review

### 5.1 %APPDATA% Verwendung

| Methode | Status | Korrekt? |
|---------|--------|----------|
| `appdata_dir()` → `%APPDATA%/Sidekick` | ✅ | ✅ |
| `get_state_dir()` → `%APPDATA%/Sidekick/state` | ✅ | ✅ |
| `get_logs_dir()` → `%APPDATA%/Sidekick/logs` | ✅ | ✅ |
| `get_config_dir()` → `%APPDATA%/Sidekick/config` | ✅ | ✅ |
| `get_runtime_dir()` → `%APPDATA%/Sidekick/runtime` | ✅ | ✅ |

### 5.2 Default-Werte

| Feld | Default | Status |
|------|---------|--------|
| `hermes_path` | Automatisch relativ zum EXE-Pfad | ✅ |
| `python_path` | `"python"` | ✅ |
| `preferred_port` | `8787` | ✅ |
| `auto_start` | `false` | ✅ |
| `auto_restart` | `false` | ✅ |

### 5.3 JSON-Persistenz

| Operation | Status |
|-----------|--------|
| `load_settings()` — Datei existiert nicht → Defaults | ✅ |
| `load_settings()` — Datei korrupt → Defaults (stilles Fallback) | ✅ |
| `save_settings()` — Config-Verzeichnis wird erstellt | ✅ |
| `save_settings()` — Pretty-Print JSON | ✅ |
| `save_settings()` — Fehlerbehandlung (Result<(), String>) | ✅ |

---

## 6. Ports/Health Review

### 6.1 Port-Fallback-Logik

| Stufe | Kandidat | Verhalten |
|-------|----------|-----------|
| 1 | `preferred` (8787) | ✅ Direkter Bind-Versuch |
| 2 | `preferred + 1` (8788) | ✅ |
| 3 | `preferred + 2` (8789) | ✅ |
| 4 | Scan von `max(preferred+3, 8790)` aufwärts | ✅ |
| 5 | OS-Pick (Port 0) | ✅ Letzte Ressource |

**Issue 6.1.1:** Wenn `preferred_port` sehr hoch ist (z. B. 65533), können `saturating_add` auf 65535 limitieren, und der Scan-Bereich `start..u16::MAX` wird sehr klein. Der OS-Pick (Port 0) fängt das ab, aber es ist ein Edge Case.

### 6.2 Healthcheck-Response-Format

`check_health()` erwartet `{"status": "ok"}` als Erfolgsantwort. Das ist kompatibel mit Hermes WebUI's `/health` Endpoint.

| Response-Typ | Behandlung |
|--------------|------------|
| `{"status": "ok"}` | ✅ `HealthStatus::Ok` |
| `{"status": "degraded"}` | ✅ `HealthStatus::Error("Unexpected status: 'degraded'")` |
| Keine Response (Timeout) | ✅ `HealthStatus::Starting` |
| Ungültiges JSON | ✅ `HealthStatus::Error("Failed to parse...")` |

---

## 7. Issues Found

| # | Severity | File | Issue | Fix |
|---|----------|------|-------|-----|
| 1 | **HIGH** | `app/app.js:290` vs `src-tauri/src/main.rs:81` | JS ruft `invoke('load_settings', ...)` auf, aber der Tauri-Command heißt `get_settings`. Aufruf schlägt zur Runtime fehl. | JS muss `invoke('get_settings', ...)` verwenden. |
| 2 | **HIGH** | `app/app.js:310` vs `src-tauri/src/main.rs:87` | JS sendet `{ settings: settings }` aber Rust-Parameter heißt `settings_data`. Tauri matched nach Parameter-Namen → der Aufruf schlägt fehl. | JS muss `{ settings_data: settings }` senden. |
| 3 | **HIGH** | `app/app.js:248` vs `src-tauri/src/main.rs` | JS ruft `invoke('open_logs', ...)` auf, aber dieser Tauri-Command existiert nicht in main.rs. | Command `open_logs` in main.rs registrieren (analog zu `open_appdata`). |
| 4 | **HIGH** | `app/app.js:273` vs `src-tauri/src/main.rs:68` | JS ruft `invoke('open_in_browser', { url })` auf, aber der Command heißt `open_browser(port: u16)`. Signatur und Parametername stimmen nicht. | JS muss `invoke('open_browser', { port: port })` verwenden. |
| 5 | **HIGH** | `app/app.js:338` vs `src-tauri/src/supervisor.rs:430` | JS `pollStatus()` erwartet von `get_status` ein Objekt `{ status, port, last_error }`, aber Rust gibt einen Plain-String zurück (`"stopped"`, `"running"`, etc.). `status.port` und `status.last_error` sind immer `undefined`. | `get_status()` sollte ein Struct mit `status`, `port`, `last_error` zurückgeben, oder JS muss den String parsen müssen. |
| 6 | **MEDIUM** | `src-tauri/src/health.rs` | `health.rs` wird als Modul deklariert (`mod health;` in main.rs) aber nie aufgerufen. Die Funktion `check_health()` ist totes Gencode. | Entweder Healthcheck in Supervisor integrieren oder `mod health;` entfernen. |
| 7 | **MEDIUM** | `README.md` | README referenziert `src-tauri/src/logs.rs`, `docs/WINDOWS_APP.md`, `docs/ARCHITECTURE.md`, `docs/TROUBLESHOOTING.md` — diese Dateien existieren nicht. | README an tatsächliche Projektstruktur anpassen oder fehlende Dateien anlegen. |
| 8 | **LOW** | `app/hermes-icons.html` | Icon-Sammlung existiert, wird aber nicht in `index.html` eingebunden. | `<link rel="import">` oder inline usage hinzufügen, oder Datei entfernen. |
| 9 | **LOW** | `src-tauri/tauri.conf.json:27` | `"targets": "all"` ist kein gültiger Tauri v2 Bundle-Target. Gültig wäre z. B. `["msi", "nsis"]`. | Korrektes Array-Format für bundle targets verwenden. |
| 10 | **LOW** | `src-tauri/src/settings.rs:153` | `to_windows_path()` ersetzt `/` durch `\` — das ist korrekt für Windows, könnte aber auf UNC-Pfaden oder gemischten Pfaden Probleme machen. | Kein dringender Fix, aber Dokumentation erwähnen. |
| 11 | **INFO** | `runtime/requirements.lock.txt` | Enthält nur `pyyaml>=6.0`. Sollte ein gepinnter Lock sein (Version einfrieren), ist aber eine Range. | Version auf konkrete Version pinnen, z. B. `pyyaml==6.0.2`. |
| 12 | **INFO** | `src-tauri/src/supervisor.rs:239` | `state_dir.trim_end_matches('/')` — In Windows-Kontext werden Backslashes verwendet. Der Trim könnte ins Leere laufen. | `trim_end_matches(|c| c == '/' || c == '\\')` für Windows-Kompatibilität. |

---

## 8. Open Points

- **Healthcheck-Integration:** `health.rs` ist vollständig implementiert und getestet, wird aber vom Supervisor nicht verwendet. Sollte der Supervisor nach dem Start einen Healthcheck-Polling-Loop durchführen? Derzeit setzt `start_hermes_with()` den Status sofort auf `"running"`, ohne zu prüfen ob der Server wirklich antwortet.
- **Auto-Restart / Watchdog:** `Settings.auto_restart` (in `settings.rs` Zeile 24) wird nirgendwo implementiert. Der Supervisor hat keinen Watchdog-Mechanismus der einen abgestürzten Hermes-Prozess neu startet.
- **Zustandsmaschine Inkonsistenz:** JS `pollStatus()` verwendet Status-Werte `"starting"`, `"running"`, `"stopping"`, `"restarting"`, `"idle"`, `"error"`. Rust/Supervisor verwendet `"stopped"`, `"starting"`, `"running"`, `"error"`. Der Wert `"idle"` (JS) vs `"stopped"` (Rust) ist inkonsistent. `"stopping"` und `"restarting"` existieren nur in JS.
- **Dev-Modus Simulation:** In `app.js` (Zeilen 415-422) wird im Dev-Modus (kein Tauri) nach 3s `"starting"` und nach 6s `"running"` simuliert. Die WebUI wird auf Port 8787 geladen. Das ist sinnvoll für UI-Tests, aber die Werte sollten ggf. konfigurierbar sein.
- **Settings-Felder im Frontend:** `app.js` `collectSettings()` verwendet andere Feldnamen (`port`, `autostart`, `python_path`, `hermes_path`) als das Rust Struct Settings (`preferred_port`, `auto_start`, `python_path`, `hermes_path`). JS `loadSettings()` mapped beim Anwenden nur wenn Felder existieren (`s.port`, `s.autostart`), aber da der Rust-Command `load_settings` nicht existiert, wird der Dev-Fallback verwendet.
- **Keine `open_logs`-Funktion in Rust:** `open_logs()` in JS soll vermutlich den Logs-Ordner im Explorer öffnen. Der Pfad wäre `%APPDATA%\Sidekick\logs\`. Ein analoger Command zu `open_appdata` fehlt.
- **Test-Isolation:** Die Tests in supervisor.rs modifizieren den globalen Singleton (`OnceLock<Mutex<HermesSupervisor>>`). Tests laufen in Rust standardmäßig parallel, was zu Race Conditions zwischen Tests führen kann: ein Test setzt den Status auf `RUNNING`, ein anderer erwartet `STOPPED`.

---

## 9. Zusammenfassung

**Gesamtqualität:** Gute Projektstruktur mit sauberer Architektur, Windows-kompatibler Supervisor und vollständigem Settings-System. Die Hauptprobleme liegen in der **JS-Rust-Kommunikation (IPC)**:

- **4 HIGH Issues:** Falsche oder fehlende Tauri-Command-Namen und Parameter in `app.js` vs `main.rs`. Die App würde zur Laufzeit mit IPC-Fehlern abstürzen.
- **2 MEDIUM Issues:** Toter Code (`health.rs` nicht eingebunden) und veraltete README-Referenzen.
- **3 LOW Issues:** Nicht eingebundene Icon-Datei, Tauri-Konfigurationsdetail, Pfad-Handling.

**Empfehlung:** JS-Seite (`app.js`) an die tatsächlichen Rust-Commands anpassen, `health.rs` in den Supervisor integrieren, und README korrigieren.

---

## 10. Prüfmatrix-Ergebnis

| Bereich | Ergebnis |
|---------|----------|
| 1. Struktur | ✅ Alle Kern-Dateien vorhanden, 4 README-Referenzen fehlerhaft |
| 2. Rust-Code | ⚠️ Module ok, health.rs tot, 3 fehlende Tauri-Commands |
| 3. App-UI | ⚠️ 6 IPC-Fehlanpassungen zwischen JS und Rust |
| 4. Supervisor | ✅ Windows-kompatibel, saubere Kill-Strategie, gute Thread-Safety |
| 5. Settings | ✅ Korrekte %APPDATA%-Nutzung, Defaults ok, JSON-Persistenz sauber |
| 6. Ports/Health | ✅ Port-Fallback robust, Healthcheck-Format korrekt |
