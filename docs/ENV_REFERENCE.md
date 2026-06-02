# Environment-Variablen-Referenz — Sidekick

> Stand: 2026-05-15 | Quelle: `supervisor.rs`, `config.py`, `settings.rs`

---

## 1. Vom Supervisor gesetzte Variablen

Diese Variablen setzt `HermesSupervisor::start_hermes_with()` beim Start des
WebUI-Prozesses. Sie überschreiben alle Defaults im WebUI-Server.

| Variable | Supervisor-Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_HOST` | `127.0.0.1` | **Bind-Address.** Nur Loopback – keine Remote-Zugriffe. |
| `HERMES_WEBUI_PORT` | `8787` (dynamisch) | **Port.** Tatsächlicher Wert via `ports::find_free_port()` ermittelt. Fallback: 8787→8788→8789→freier Port. |
| `HERMES_WEBUI_STATE_DIR` | `%APPDATA%\Sidekick\state\hermes-webui` | **State-Verzeichnis.** Enthält `sessions/`, `settings.json`, `workspaces.json` etc. Wird automatisch erstellt. |
| `PYTHONIOENCODING` | `utf-8` | **UTF-8 für stdio.** Stellt sicher, dass Pfade mit Nicht-ASCII-Zeichen korrekt verarbeitet werden. |

---

## 2. Vom WebUI-Server gelesene Variablen

Diese Variablen werden in `api/config.py` ausgewertet. Sidekick setzt sie **nicht**
aktiv – sie fallen auf ihre jeweiligen Defaults oder werden durch die
auto-discover Logik bestimmt.

### Netzwerk

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_HOST` | `127.0.0.1` | Wird vom Supervisor überschrieben (siehe Abschnitt 1). |
| `HERMES_WEBUI_PORT` | `8787` | Wird vom Supervisor überschrieben (siehe Abschnitt 1). |
| `HERMES_WEBUI_TLS_CERT` | (leer) | Pfad zum TLS-Zertifikat für HTTPS. Wenn gesetzt, wird HTTPS aktiviert. |
| `HERMES_WEBUI_TLS_KEY` | (leer) | Pfad zum TLS-Private-Key. Erforderlich wenn `HERMES_WEBUI_TLS_CERT` gesetzt ist. |

### State & Pfade

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_STATE_DIR` | `~/.hermes/webui` | Wird vom Supervisor überschrieben (siehe Abschnitt 1). |
| `HERMES_WEBUI_DEFAULT_WORKSPACE` | `~/.hermes/webui/workspace` | Standard-Workspace für neue Sessions. |
| `HERMES_CONFIG_PATH` | `~/.hermes/config.yaml` | Pfad zur Hermes-Config (Provider, Modelle, etc.). |
| `HERMES_HOME` | `~/.hermes` | Basis-Verzeichnis für Hermes-Zustand (Credentials, Config, Agent-Module). |

### Agent & Python

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_AGENT_DIR` | auto-discover | Expliziter Pfad zum Hermes-Agent-Checkout. Überspringt die auto-discover-Logik. |
| `HERMES_WEBUI_PYTHON` | auto-discover | Expliziter Python-Pfad für Agent-Operationen. |
| `HERMES_HOME` | `~/.hermes` | Agent-Home-Verzeichnis; dient u. a. als Basis für Agent-Discovery. |

### Authentifizierung

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_PASSWORD` | (leer) | **Passwort-Auth.** Wenn gesetzt, müssen alle API-Requests ein gültiges Passwort mitliefern. Ohne Wert ist die API offen. |
| `HERMES_WEBUI_SKIP_ONBOARDING` | (leer) | Überspringt den First-Run-Onboarding-Wizard (`"1"` oder `"true"`). |

### Testing

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_TEST_PORT` | (leer) | Fixierter Test-Port (überschreibt Port-Fallback in Tests). |
| `HERMES_WEBUI_TEST_STATE_DIR` | (leer) | Isoliertes State-Verzeichnis für Tests. |
| `HERMES_WEBUI_TEST_NETWORK_BLOCK` | (leer) | Blockiert ausgehende Nicht-Loopback-Netzwerkverbindungen (`"1"` oder `"true"`). |

### Bot

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_WEBUI_BOT_NAME` | `Hermes` | Anzeigename des Bots in der UI. |
| `HERMES_WEBUI_DEFAULT_MODEL` | (leer) | Modell-Override; unset bedeutet Provider-Default. |

---

## 3. Von Sidekick (Rust) genutzte Variablen

Diese Umgebungsvariablen werden vom Supervisor und den Settings-Komponenten
verwendet.

| Variable | Default | Beschreibung |
|---|---|---|
| `APPDATA` | (Windows) | Basis für `%APPDATA%\Sidekick\…` – State, Config, Logs, Runtime. |
| `HERMES_WEBUI_HOST` | `127.0.0.1` | (siehe Abschnitt 1) |
| `HERMES_WEBUI_PORT` | `8787` | (siehe Abschnitt 1) |
| `HERMES_WEBUI_STATE_DIR` | `%APPDATA%\Sidekick\state\hermes-webui` | (siehe Abschnitt 1) |
| `PYTHONIOENCODING` | `utf-8` | (siehe Abschnitt 1) |

---

## 4. Vom WebUI (agent-seitig) genutzte Variablen

| Variable | Default | Beschreibung |
|---|---|---|
| `HERMES_EXEC_ASK` | (leer) | Wenn `"1"`, werden gefährliche Kommandos vor Ausführung bestätigt (Approval Gate). |
| `HERMES_SESSION_KEY` | (leer) | Session-ID für das Approval-Tool. |
| `TERMINAL_CWD` | (leer) | Aktuelles Arbeitsverzeichnis für Terminal-Sessions. |

---

## 5. Pfad-Übersicht (%APPDATA%\Sidekick)

| Verzeichnis | Funktion |
|---|---|
| `%APPDATA%\Sidekick\` | Basis-Verzeichnis |
| `%APPDATA%\Sidekick\state\` | Allgemeiner App-State (`get_state_dir()`) |
| `%APPDATA%\Sidekick\state\hermes-webui\` | `HERMES_WEBUI_STATE_DIR` – Sessions, Workspaces, Settings |
| `%APPDATA%\Sidekick\logs\` | App-Logs |
| `%APPDATA%\Sidekick\config\` | Settings (JSON) |
| `%APPDATA%\Sidekick\runtime\` | Python-Venv, Bootstrap-Scripts |

---

## 6. Beispielhafter Start (vollständiger Env-Satz)

```
HERMES_WEBUI_HOST=127.0.0.1
HERMES_WEBUI_PORT=8788
HERMES_WEBUI_STATE_DIR=C:\Users\user\AppData\Roaming\Sidekick\state\hermes-webui
HERMES_WEBUI_PASSWORD=
HERMES_WEBUI_AGENT_DIR=C:\Users\user\.hermes\hermes-agent
HERMES_HOME=C:\Users\user\.hermes
PYTHONIOENCODING=utf-8
```

Entspricht dem Start durch den Tauri-Supervisor (exkl. `HERMES_WEBUI_AGENT_DIR`
und `HERMES_HOME`, die WebUI-seitig auto-discovered werden).
