# Windows Startstrategie-Bericht — Sidekick

> Erstellt: 2026-05-15 | Basis: Tauri 2 + WebView2 + Hermes WebUI

---

## 1. Benötigte Runtime

| Komponente | Version | Verfügbarkeit unter Windows |
|---|---|---|
| **Python** | ≥ 3.7 (empfohlen: 3.10–3.12) | Manuell installieren oder embedded Python |
| **WebView2** | Evergreen Runtime | Windows 11: vorinstalliert<br>Windows 10: vorinstalliert ab 1803 (Edge-Update)<br>Fallback: [Evergreen Installer](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) |
| **MSVC Redistributable** | 2022 | Wird oft mit Windows Update geliefert; ggf. installieren |
| **pip + venv** | stdlib (Python ≥ 3.3) | In jeder Python-Installation enthalten |
| **PyYAML** | ≥ 6.0 | Einzige Python-Dependency (requirements.txt) |
| **Hermes Agent** | optional (auto-discover) | Wird via `HERMES_WEBUI_AGENT_DIR` oder standard Pfaden gefunden |

**WebUI-spezifisch:** Nur `pyyaml>=6.0` als Abhängigkeit — der Server läuft rein mit stdlib + yaml. Alle ML/Agent-Dependencies leben im Hermes-Agent-Venv.

---

## 2. Bootstrap-Strategie (Empfehlung)

### Phase 1 — Runtime-Prüfung (Tauri Supervisor/Rust)

```
1. Prüfe ob Python auf PATH (python --version)
   - Falls nein: Dialog mit Download-Link https://python.org
   - Min version check: 3.7+

2. Prüfe ob WebView2 verfügbar
   - Registry: HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}
   - Falls fehlt: Evergreen Bootstrapper starten

3. Prüfe MSVC Redistributable
   - Registry: HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64
   - Falls fehlt: Installer starten oder warnen
```

### Phase 2 — Venv + Dependencies (PowerShell oder Rust direkt)

```
4. Venv anlegen: F:/finalbrowser/runtime/.venv/
   - python -m venv .venv (symlinks=false für Windows-Kompatibilität)
   - .venv/Scripts/python -m pip install --upgrade pip
   - .venv/Scripts/python -m pip install -r vendor/hermes-webui/requirements.txt

5. State-Verzeichnis anlegen: %APPDATA%\Sidekick\
   - State, Sessions, Logs, Settings hier

6. Hermes Agent discovery
   - HERMES_WEBUI_AGENT_DIR → %APPDATA%\.hermes\hermes-agent → sibling ../hermes-agent
   - Falls nicht gefunden und hermes CLI existiert: Pfad aus shebang extrahieren
```

### Phase 3 — Start (Tauri Supervisor/Rust)

```
7. Freien Port finden (8787 → 8788 → 8789 → ...)
8. Healthcheck-Loop alle 500ms, max 25s
9. WebView2 auf http://localhost:{port} navigieren
10. Bei Fehlschlag: Prozess killen, Log ausgeben, Restart-Button
```

### PowerShell-Skizze (`runtime/bootstrap_venv.ps1`)

```powershell
param(
    [string]$VendorDir = "F:\finalbrowser\vendor\hermes-webui",
    [string]$VenvDir = "F:\finalbrowser\runtime\.venv"
)

# Python finden
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) { throw "Python nicht gefunden" }

# Venv erstellen (ohne Symlinks — Windows-kompatibel)
& $python -m venv --without-pip $VenvDir
& $python -m venv $VenvDir

# Upgrade pip + install deps
& "$VenvDir\Scripts\python" -m pip install --upgrade pip --quiet
& "$VenvDir\Scripts\python" -m pip install -r "$VendorDir\requirements.txt" --quiet

Write-Output "OK: venv ready at $VenvDir"
```

---

## 3. Risiken und Mitigationen

### Pfade mit Leerzeichen (z. B. `C:\Users\Max Mustermann\...`)

| Risiko | Mitigation |
|---|---|
| PowerShell-Scripte brechen bei unquoteten Parametern | **Immer** `"$path"` (double-quotes) verwenden |
| `subprocess.Popen(["python", path])` in Rust ist sicher | `Command::new("python").arg(venv_python)` — Rust's `Command` escaped korrekt |
| `os.environ` in bootstrap.py parst Pfade korrekt | `Path()` aus pathlib handhabt Spaces nativ |
| **Tipp:** `bootstrap.py` von hermes-webui scheitert bereits bei `ensure_supported_platform()` auf Windows | Sidekick muss eigenen Bootstrap schreiben |

### Encoding / UTF-8

| Risiko | Mitigation |
|---|---|
| PowerShell pipe output ist OEM-Codepage | `[Console]::OutputEncoding = [Text.Encoding]::UTF8` im Script setzen |
| server.py setzt `PYTHONIOENCODING=utf-8` | Dockerfile gibt das vor — für Sidekick in der venv-Python env mitgeben |
| Pfade mit Nicht-ASCII-Zeichen | Alle `pathlib`-Operationen nutzen `encoding="utf-8"`; `Path.read_text(encoding="utf-8")` wie in bootstrap.py |

### Shell-Kommandos (Sicherheit)

| Risiko | Mitigation |
|---|---|
| `subprocess.run(..., shell=True)` niemals mit User-Input | `bootstrap.py` nutzt nur Listen-Form → sicher |
| PowerShell `Invoke-Expression` vermeiden | Kein `iex`, nur `& $exe @args` |
| Hermes-Installer (`curl ... \| bash`) funktioniert nur unter Unix/WSL | Sidekick nutzt WSL nicht → Hermes-Installation muss packaged oder via pip erfolgen |

### AppData vs. User-Verzeichnisse

| Risiko | Mitigation |
|---|---|
| `%APPDATA%\Sidekick\` kann auf Netzwerklaufwerk liegen → Latenz | Fallback auf `%LOCALAPPDATA%\Sidekick\` + Konfiguration |
| Logs und State dürfen nicht im Programm-Verzeichnis landen | `%APPDATA%\Sidekick\logs\`, `%APPDATA%\Sidekick\state\` |
| `HERMES_WEBUI_STATE_DIR` per env setzbar lassen | Ermöglicht Power-Usern Umleitung |

### WebView2

| Risiko | Mitigation |
|---|---|
| Fehlt auf Windows 10 LTSC/Server Core | Prüfung via Registry + Download-Link im UI |
| WebView2 Runtime wird durch Edge-Update aktualisiert | Kein Handling nötig — automatisch |
| Tauri 2 benötigt WebView2 für Hauptfenster | Vor Start prüfen — ohne WebView2 kein App-Start möglich |

---

## 4. Zusammenfassung

**Sidekick benötigt:**
- Python ≥ 3.7 (vorinstalliert prüfen oder Bundle mit embedded Python)
- WebView2 Runtime (≥ Windows 10 1803 oder via Evergreen Installer)
- pyyaml≥6.0 (wird via pip in venv installiert)
- Hermes Agent (optional, auto-discover)

**Kritischer Punkt:** Hermes WebUI's `bootstrap.py` unterstützt kein natives Windows (`ensure_supported_platform()` wirft RuntimeError). Sidekick muss daher **einen eigenen Bootstrap implementieren** — entweder in Rust (Tauri Supervisor) oder als PowerShell-Script.

**Empfohlener Ansatz:** Rust-basierte Runtime-Prüfung + PowerShell-Script für Venv-Erstellung. Der Tauri-Supervisor (src-tauri/src/supervisor.rs) übernimmt: Healthcheck, Port-Fallback, Prozess-Lifecycle.
