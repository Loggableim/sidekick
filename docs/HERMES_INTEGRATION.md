# Hermes WebUI Integration in Sidekick

> Stand: 2026-05-15 | Projekt: Sidekick (F:/finalbrowser)

---

## 1. Überblick

Sidekick bindet **Hermes WebUI** als unveränderte Vendor-Komponente ein.
Das gesamte WebUI liegt unter `vendor/hermes-webui/` und wird **unangetastet**
gelassen – Sidekick steuert es ausschliesslich über Environment-Variablen und
Prozess-Lifecycle (Supervisor).

**Keine Code-Änderungen an `vendor/hermes-webui/`** – weder Patches, Forks,
noch Konfigurations-Dateien innerhalb des Vendor-Verzeichnisses.

---

## 2. Verzeichnis-Layout

```
F:/finalbrowser/
├── vendor/
│   └── hermes-webui/          ← UNANGETASTET (Git-Submodul oder Clone)
│       ├── server.py          ← Einstiegspunkt (python server.py)
│       ├── api/
│       │   ├── config.py      ← Liest Env-Vars (HOST, PORT, STATE_DIR, …)
│       │   ├── routes.py      ← Health-Endpoint (GET /health)
│       │   └── …
│       └── requirements.txt
├── src-tauri/
│   └── src/
│       ├── supervisor.rs      ← HermesSupervisor (start/stop/restart)
│       ├── health.rs          ← Healthcheck-Polling (GET /health)
│       ├── ports.rs           ← Port-Fallback (8787 → 8788 → …)
│       └── settings.rs        ← Settings + AppData-Pfade
├── docs/
│   ├── HERMES_INTEGRATION.md  ← Dieses Dokument
│   └── ENV_REFERENCE.md       ← Environment-Variablen-Referenz
└── runtime/
    └── .venv/                 ← Python-Venv (wird vom Bootstrap angelegt)
```

---

## 3. Startbefehl

Der Tauri-Supervisor (Rust) startet Hermes WebUI als Child-Prozess:

```
<python_path> server.py
```

- **Working Directory:** `vendor/hermes-webui/` (via `Command::current_dir`)
- **Stdout/Stderr:** Gepiped → Log-Ringbuffer (siehe Abschnitt 6)
- **Python:** Aus `settings.python_path` (default: `python`, via Venv-Pfad)

### Environment-Variablen (vom Supervisor gesetzt)

| Variable | Wert | Quelle |
|---|---|---|
| `HERMES_WEBUI_HOST` | `127.0.0.1` | Hartcodiert in `supervisor.rs` |
| `HERMES_WEBUI_PORT` | dynamisch (8787, 8788, …) | `ports::find_free_port()` |
| `HERMES_WEBUI_STATE_DIR` | `%APPDATA%\Sidekick\state\hermes-webui` | `settings::get_state_dir() + "/hermes-webui"` |
| `PYTHONIOENCODING` | `utf-8` | Hartcodiert in `supervisor.rs` |

Der WebUI-Server (`api/config.py`) liest diese Variablen und konfiguriert sich
entsprechend. Fehlende Variablen fallen auf sinnvolle Defaults zurück
(z. B. `PORT=8787`, `HOST=127.0.0.1`).

---

## 4. Port-Fallback

Definiert in `src-tauri/src/ports.rs`:

1. **Preferred Port (8787):** Sofortversuch via `TcpListener::bind`.
2. **Fallback 1 (8788):** Wenn 8787 belegt.
3. **Fallback 2 (8789):** Wenn 8788 belegt.
4. **Scan (8790+):** Linearer Scan nach oben bis ein freier Port gefunden wird.
5. **OS-Pick (0):** Letzte Ressource – OS wählt einen freien ephemeren Port.

Die Funktion `find_free_port(preferred: u16)` gibt immer einen gültigen Port
zurück oder panickt nur bei einem extrem unwahrscheinlichen OS-Fehler (keine
freien Ports auf 127.0.0.1).

---

## 5. Healthcheck

Definiert in `src-tauri/src/health.rs`.

### Endpoint

```
GET http://127.0.0.1:{port}/health
```

### Erfolgsantwort (HTTP 200)

```json
{
  "status": "ok",
  "sessions": 0,
  "active_streams": 0,
  "active_runs": 0,
  "uptime_seconds": 12.3,
  "accept_loop": {
    "total_requests": 42,
    "last_request_at": 1715760000.0
  }
}
```

### Degraded-Antwort (HTTP 503)

```json
{
  "status": "degraded",
  "sessions": 0,
  "active_streams": 1,
  "active_runs": 0,
  "uptime_seconds": 60.0,
  "accept_loop": { ... }
}
```

### Clientseitiger Healthcheck (Rust)

```rust
pub fn check_health(port: u16, timeout_secs: u64) -> Result<HealthStatus, String>
```

- **Polling-Intervall:** 500 ms
- **Default-Timeout:** 25 Sekunden (entspricht ~50 Polls)
- **Erfolg:** `HealthStatus::Ok` bei `{"status": "ok"}`
- **Timeout:** `HealthStatus::Starting` wenn keine Antwort innerhalb des Timeouts
- **Fehler:** `HealthStatus::Error(msg)` bei unerwartetem Status, fehlerhaftem JSON
  oder Verbindungsfehlern nach dem ersten erfolgreichen Kontakt

---

## 6. Log-Erfassung

Definiert in `supervisor.rs`:

- **stdout/stderr** werden via `Stdio::piped()` umgeleitet.
- Zwei **Reader-Threads** lesen zeilenweise aus den Pipes.
- Einträge werden mit Prefix `[out]` (stdout) bzw. `[err]` (stderr) markiert.
- **Ringbuffer:** Maximal 1000 Einträge, älteste werden verworfen.
- **API `get_logs()`:** Gibt die letzten 100 Einträge zurück.
- Thread-safe durch separaten `Arc<Mutex<Vec<String>>>` für Logs (kein
  Deadlock-Risiko mit dem Supervisor-Mutex).

### Log-Format

```
[out] [webui] {"ts":"2026-05-15T12:00:00Z","method":"GET","path":"/health","status":200,"ms":1.2}
[out]   Hermes Web UI listening on http://127.0.0.1:8787
[err] [webui] ERROR GET /api/something
[err] Traceback (most recent call last):
```

---

## 7. Hermes Agent (optional)

Hermes WebUI benötigt den Hermes Agent **nicht** zwingend zum Starten.
Sidekick startet nur die WebUI – der Agent wird bei Bedarf auto-discovered.

### Discover-Reihenfolge (`api/config.py`)

1. `HERMES_WEBUI_AGENT_DIR` (Env-Var, explizite Angabe)
2. `$HERMES_HOME/hermes-agent` (z. B. `~/.hermes/hermes-agent`)
3. `../hermes-agent` (sibling zum WebUI-Verzeichnis)
4. `~/.hermes/hermes-agent` (Common Path)
5. `~/hermes-agent` (Flat Layout)
6. `$XDG_DATA_HOME/hermes-agent`
7. Systemweite Pfade (`/opt/hermes-agent`, `/usr/local/hermes-agent`)

Falls kein Agent gefunden wird, läuft die WebUI trotzdem – jedoch ohne
Agent-Features (keine Provider, keine Sessions, keine Tool-Calls).

### Sidekick-spezifisch

Sidekick setzt **weder** `HERMES_WEBUI_AGENT_DIR` noch `HERMES_HOME` im
Supervisor. Die auto-discover Logik des WebUI-Servers findet den Agenten
automatisch – oder lässt die WebUI ohne Agent-Features laufen.

Soll explizit ein Agent-Pfad gesetzt werden, kann dies via Settings
oder Umgebungsvariable erfolgen.

---

## 8. Lifecycle (Supervisor)

### Zustandsmaschine

```
STOPPED → STARTING → RUNNING → STOPPED
                   ↘ ERROR ↗
```

### Status-Werte

| Status | Bedeutung |
|---|---|
| `stopped` | Kein Prozess läuft (Initialzustand) |
| `starting` | `Command::spawn` wurde aufgerufen |
| `running` | Prozess läuft |
| `error` | Python nicht gefunden oder Spawn fehlgeschlagen |

### Kill-Strategie (Windows)

1. **Graceful:** `taskkill /PID <pid>` (sendet Ctrl+C)
2. **Wait:** Bis zu 3 Sekunden Polling auf Prozess-Exit
3. **Force:** `taskkill /F /PID <pid>` (Kill inkl. Prozessbaum)
4. **Finalize:** `child.wait()` zur Ressourcen-Freigabe

---

## 9. Settings / Konfiguration

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

`hermes_path` wird automatisch relativ zum EXE-Pfad aufgelöst
(`../vendor/hermes-webui`). Der default `python_path` ist `python` – typischerweise
überschreibt der Bootstrap den Pfad auf das Venv.

---

## 10. Sicherheitshinweise

- Hermes WebUI bindet standardmässig auf **127.0.0.1** (loopback only).
- Ohne `HERMES_WEBUI_PASSWORD` ist die API ungeschützt – jedes lokale Programm
  kann auf Sessions und Memory zugreifen.
- Der Supervisor startet Hermes mit den Rechten des Sidekick-Prozesses.
- Logs können sensitive Daten enthalten (Prompts, Responses) – Zugriff auf
  `get_logs()` sollte in der Tauri-Bridge eingeschränkt werden.

---

## 11. Fehlerbehandlung

| Problem | Verhalten |
|---|---|
| Python nicht gefunden | Supervisor → `STATUS_ERROR`, Fehlermeldung mit Pfad |
| Port belegt | `ports.rs` sucht nächsten freien Port (8787→8788→8789→…) |
| WebUI startet nicht (Spawn-Fehler) | Supervisor → `STATUS_ERROR`, Log mit OS-Fehler |
| WebUI startet, aber /health antwortet nicht | Healthcheck-Poller → `HealthStatus::Starting` nach Timeout |
| WebUI stürzt nach Start ab | Reader-Threads terminieren, Status bleibt `running` (kein Watchdog – geplant) |
