# Sidekick

Eine einfache, stabile Windows-Desktop-App die Hermes WebUI lokal startet, überwacht und in einer nativen Tauri + WebView2 Hülle anzeigt.

**Status:** Initiale Projektstruktur — MVP 1 in Entwicklung.

## Ziel

Sidekick wandelt das bestehende [Hermes WebUI](https://github.com/nesquena/hermes-webui) (Python) in eine Windows-Desktop-App um. Der Fokus liegt auf einer simplen, stabilen Native-Hülle, NICHT auf einem vollständigen Browser.

## Architektur (geplant)

```
sidekick/
├── src-tauri/           # Tauri 2 Rust-App
│   ├── src/
│   │   ├── main.rs      # App-Einstieg
│   │   ├── supervisor.rs # Hermes-WebUI-Child-Prozess-Manager
│   │   ├── ports.rs     # Port-Auswahl/Fallback
│   │   ├── health.rs    # Healthcheck-Polling
│   │   ├── logs.rs      # Log-Management
│   │   └── settings.rs  # Persistente Settings
│   └── tauri.conf.json
├── app/                 # Control-UI (eingebettet in WebView)
│   ├── index.html
│   ├── app.js
│   └── styles.css
├── vendor/              # Externe Komponenten (read-only)
│   └── hermes-webui/    # Hermes WebUI als Upstream-Vendor
├── runtime/             # Python-Runtime-Management
│   ├── bootstrap_venv.ps1
│   └── requirements.lock.txt
├── scripts/             # Dev/Build-Skripte
│   ├── dev_start.ps1
│   └── build_windows.ps1
├── docs/                # Dokumentation
│   ├── WINDOWS_APP.md
│   ├── ARCHITECTURE.md
│   └── TROUBLESHOOTING.md
└── README.md
```

### Prinzipien

- **Hermes WebUI bleibt Upstream/Vendor** — minimale Änderungen, eigenes Projekt drumherum
- **Kein WSL, kein Docker** — alles native Windows (Python venv + WebView2)
- **AppData für State** — `%APPDATA%\Sidekick\`
- **Port-Fallback** — 8787 → 8788 → 8789 → freier Port
- **Supervisor** — startet/stoppt/überwacht Hermes-Prozess sauber
- **Defensive Prozessführung** — keine Zombies, sauberes Kill beim App-Exit

### MVP 1 Akzeptanzkriterien

- [ ] App startet unter Windows per Dev-Kommando
- [ ] Hermes WebUI startet aus der App heraus
- [ ] App findet freien Port
- [ ] WebUI wird nach Healthcheck eingebettet
- [ ] Logs sind sichtbar (Button)
- [ ] Restart/Stop funktionieren
- [ ] AppData wird genutzt
- [ ] Keine WSL/Docker-Pflicht
- [ ] README erklärt Setup und Build

### MVP 2 (nur nach stabiler MVP 1)

- Tray-Icon
- Auto-Start/Auto-Restart
- Settings-Seite
- In-Browser öffnen
- AppData-Ordner öffnen
- Session-Reset

## Entwicklung

Siehe `docs/WINDOWS_APP.md` für Setup und Build.

## Lizenz

MIT
