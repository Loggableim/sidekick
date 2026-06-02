# Sidekick

Dein lokaler KI-Assistent für Windows. Läuft standalone, ohne Cloudzwang.

**Status:** Open Beta · [Jetzt herunterladen](https://lastbrowser.com/sidekick/)

Sidekick ist eine **native Windows-Desktop-App**, die dir einen vollwertigen KI-Assistenten direkt auf deinen Rechner bringt. Chat, Tasks, Skills, Spaces — alles in einer App, ohne Browser, ohne Cloud.

![Sidekick](assets/sidekick/sidekick-logo-01-smile-spark.svg)

## Features

- **Chat** – Fragen stellen, Texte entwerfen, Inhalte analysieren
- **Tasks & Todos** – Aufgaben mit Kontext aus Gesprächen verwalten
- **Skills** – Vorgefertigte Workflows für Recherche, Schreiben, Analyse
- **Spaces** – Projekte sauber trennen mit eigenem Kontext und Verlauf
- **Lokale Modelle** – Nutze llama.cpp, Ollama & Co. – deine Daten bleiben bei dir
- **API-Connect** – Alternativ mit eigenen API-Keys (OpenAI, Anthropic, …)

## Architektur

```
sidekick/
├── src-tauri/           # Tauri 2 Rust-App
│   ├── src/
│   │   ├── main.rs      # App-Einstieg + Tauri-Commands
│   │   ├── supervisor.rs # Sidekick-Prozess-Manager + Logs
│   │   ├── ports.rs     # Port-Auswahl/Fallback
│   │   ├── health.rs    # Healthcheck-Polling
│   │   └── settings.rs  # Persistente Settings
│   └── tauri.conf.json
├── app/                 # Control-UI (WebView2)
│   ├── index.html
│   ├── app.js
│   ├── sidekick-icons.html
│   └── styles.css
├── vendor/
│   └── hermes-webui/    # Upstream Hermes WebUI (Vendor, read-only)
├── runtime/
│   ├── bootstrap_venv.ps1
│   └── requirements.lock.txt
├── scripts/
│   ├── dev_start.ps1
│   ├── build_windows.ps1
│   ├── kill_sidekick.ps1
│   └── package_windows.ps1
├── docs/
└── README.md
```

### Prinzipien

- **Native Windows-App** – Kein WSL, kein Docker, kein Browser nötig
- **Hermes WebUI als Vendor** – Upstream bleibt unverändert
- **AppData für State** – `%APPDATA%\Sidekick\`
- **Port-Fallback** – 8787 → 8788 → 8789 → freier Port
- **Prozess-Supervisor** – Sauberes Start/Stopp/Restart des Backends
- **Defensiv** – Keine Zombie-Prozesse, sauberes Kill beim Exit

## Download

| Version | Link |
|---------|------|
| **Setup** (mit Auto-Update) | [lastbrowser.com/downloads/sidekick-setup.exe](https://lastbrowser.com/downloads/sidekick-setup.exe) |
| **Portable** (ohne Installation) | [lastbrowser.com/downloads/sidekick-portable.exe](https://lastbrowser.com/downloads/sidekick-portable.exe) |
| **Update-Manifest** | [sidekick-latest.yml](https://lastbrowser.com/downloads/sidekick-latest.yml) |

## Entwicklung

Siehe `docs/WINDOWS_APP.md` für Setup und Build.

## Lizenz

**Non-Commercial:** Kostenlos für private Projekte, Studium, Hobby und nicht-kommerzielle Nutzung. Alle Features inklusive.

**Commercial:** Für gewerbliche Nutzung, Vertrieb oder Team-Einsatz ist eine individuelle Vereinbarung erforderlich.  
Kontakt: **vertrag@lastbrowser.com**

Sidekick © 2026 · Ein Produkt von [Lastbrowser](https://lastbrowser.com)
