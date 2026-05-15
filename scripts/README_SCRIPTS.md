# Sidekick – Scripts Übersicht

Dieses Verzeichnis enthält PowerShell-Skripte für Entwicklung, Build und
Paketierung von Sidekick.

## Voraussetzungen (alle Skripte)

| Tool      | Version   | Installationsanleitung                             |
|-----------|-----------|----------------------------------------------------|
| PowerShell | 5.1+      | Teil von Windows 10/11                             |
| Python     | 3.10+     | https://www.python.org/downloads/                  |
| Rust      | nightly   | https://rustup.rs/                                 |
| Cargo     | (via Rust) | Wird von rustup mitinstalliert                    |
| Node.js   | 18+       | https://nodejs.org/ (nur für Tauri CLI-Features)   |
| Git       | beliebig  | https://git-scm.com/download/win                   |

---

## 1. `dev_start.ps1` – Entwicklung starten

**Zweck:** Startet die vollständige Sidekick-Entwicklungsumgebung.

**Was passiert:**

1. **Voraussetzungsprüfung** – Prüft ob Python, Rust und Cargo installiert sind
2. **Bootstrap** – Führt `runtime/bootstrap_venv.ps1` aus (venv + Python-Deps)
3. **Port-Konfiguration** – Nutzt Port 8787 (überschreibbar via `$env:SIDEKICK_PORT`)
4. **Hermes WebUI starten** – Startet `vendor/hermes-webui/server.py` im Hintergrund
   - Setzt `HERMES_WEBUI_HOST=127.0.0.1`
   - Setzt `HERMES_WEBUI_PORT` (aus `$env:SIDEKICK_PORT` oder 8787)
   - Setzt `HERMES_WEBUI_STATE_DIR=%APPDATA%\Sidekick\webui`
5. **Tauri Dev-Modus** – Startet `cargo tauri dev` im `src-tauri/` Verzeichnis
6. **Aufräumen** – Bei Strg+C wird der Hermes WebUI-Prozess sauber beendet

**Nutzung:**

```powershell
cd F:\finalbrowser
.\scripts\dev_start.ps1
```

**Hinweise:**

- Der erste Start lädt Cargo-Crates herunter – das kann mehrere Minuten dauern.
- `runtime/bootstrap_venv.ps1` muss existieren – falls nicht, erscheint ein Hinweis.
- Hermes WebUI ist nach dem Start unter http://127.0.0.1:8787 erreichbar.

---

## 2. `build_windows.ps1` – Release bauen

**Zweck:** Erstellt eine ausführbare `.exe` Datei aus dem Tauri-Projekt.

**Was passiert:**

1. **Voraussetzungsprüfung** – Prüft Rust, Cargo, Node.js und Python
2. **Tauri CLI** – Installiert `tauri-cli` via Cargo falls nicht vorhanden
3. **Release-Build** – Führt `cargo tauri build --bundles msi` aus
4. **Binary kopieren** – Kopiert `Sidekick.exe` und das MSI (falls erstellt) nach `F:/finalbrowser/dist/`
5. **Zusammenfassung** – Zeigt Pfad und Größe der Binary an

**Nutzung:**

```powershell
cd F:\finalbrowser
.\scripts\build_windows.ps1
```

**Ausgabe:**

- `dist/Sidekick.exe` – Die ausführbare Datei
- `dist/Sidekick_*.msi` – Optionaler MSI-Installer (nur mit WiX Toolset)

---

## 3. `package_windows.ps1` – Paketieren

**Zweck:** Erstellt ein verteilbares Paket (MSI-Installer oder manuelle ZIP).

**Zwei Wege:**

### Weg A: MSI-Installer (empfohlen, benötigt WiX Toolset)

Installiere WiX Toolset v3 von https://github.com/wixtoolset/wix3/releases

Dann:
```powershell
.\scripts\package_windows.ps1
```

Das Skript erkennt WiX automatisch und erstellt ein MSI via Tauri.

### Weg B: Manuelles Paket (ohne WiX)

Falls WiX nicht installiert ist, erstellt das Skript ein manuelles
Distributionspaket in `dist/` mit:
- `Sidekick.exe` – Die Binary
- `README.md` / `README.txt` – Kurzanleitung

**Nutzung:**

```powershell
cd F:\finalbrowser
.\scripts\package_windows.ps1
```

**Einschränkungen:**

- Das Paket ist nicht code-signiert – Windows Defender/SmartScreen kann
  eine Warnung anzeigen.
- Für echte Distribution ist ein Code-Signing-Zertifikat nötig.
- Das MSI (Weg A) benötigt WiX Toolset v3 (nicht v4).
- Ohne WiX wird nur ein manuelles Paket ohne Installer erstellt.

---

## Typischer Workflow

```powershell
# 1. Entwicklung
.\scripts\dev_start.ps1

# 2. Nach fertiger Entwicklung: Build
.\scripts\build_windows.ps1

# 3. Für Distribution: Paket
.\scripts\package_windows.ps1
```

## Umgebungsvariablen

| Variable        | Beschreibung                       | Standard     |
|-----------------|------------------------------------|--------------|
| SIDEKICK_PORT   | Port für Hermes WebUI              | 8787         |
| HERMES_WEBUI_HOST | Host-Adresse                      | 127.0.0.1    |
| HERMES_WEBUI_STATE_DIR | Zustandsverzeichnis         | %APPDATA%\Sidekick\webui |

## Fehlersuche

- **"Python nicht gefunden"**: Python installieren und PATH prüfen
- **"Rust nicht gefunden"**: `rustup.rs` ausführen und `rustc --version` prüfen
- **"cargo tauri dev" startet nicht**: `cd src-tauri && cargo build` testen
- **WebUI bleibt leer**: Hermes WebUI direkt testen:
  ```
  python vendor/hermes-webui/server.py
  ```
- **Port bereits belegt**: `$env:SIDEKICK_PORT = "8788"` setzen
