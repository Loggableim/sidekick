# MVP 1.2 — Sidekick Rendering Audit

## Status: ABGESCHLOSSEN

### Ursprüngliches Problem
Hermes WebUI wurde als graues Block-Symbol in der Sidekick-App angezeigt.

### Root Cause
Die Hermes WebUI wurde via `<iframe>` in `app/index.html` geladen. Dies wurde durch folgende Sicherheitsmechanismen blockiert:

1. **X-Frame-Options / frame-ancestors**: Hermes WebUI sendet `Content-Security-Policy-Report-Only` mit `frame-ancestors 'self'`. Dadurch darf die Seite nur in iframes auf derselben Origin geladen werden.
2. **Cross-Origin**: Die Control-UI lädt von localhost:1420 (Tauri Dev) oder direkt als Datei, während Hermes WebUI auf 127.0.0.1:8787 läuft — verschiedene Origins.
3. **Sandbox-Attribut**: Der iframe hatte `sandbox="allow-scripts allow-same-origin allow-forms allow-popups"` — zusätzliche Restriktionen.
4. **WebView2-Kontext**: Tauri's WebView2 blockiert iframe-Einbettung über verschiedene Origins standardmäßig.

### Lösung
**Option A — Separate Tauri WebviewWindow (implementiert)**

Der iframe wurde vollständig entfernt. Stattdessen öffnet Sidekick Hermes WebUI in einem eigenen nativen Tauri WebviewWindow mit Label `hermes-webui`.

Vorteile:
- Keine CSP/X-Frame-Options-Probleme (top-level navigation)
- Keine Cross-Origin-Restriktionen
- Eigenes Fenster mit voller Browser-Funktionalität
- Fenster kann fokussiert, geschlossen, neu geladen werden
- Control-Shell bleibt unabhängig

### Geänderte Dateien
| Datei | Änderung |
|---|---|
| `app/index.html` | iframe entfernt, WebUI-Statuskarte eingefügt |
| `app/app.js` | iframe-Ladefunktion entfernt, `open_hermes_window`/`focus` IPC |
| `app/styles.css` | iframe/webview-styles entfernt, Statuskarte/Mode-Indikator |
| `src-tauri/src/main.rs` | `open_hermes_window`, `close_hermes_window`, `open_external_browser` Commands |
| `src-tauri/capabilities/default.json` | webview/window permissions ergänzt |
| `src-tauri/src/supervisor.rs` | `stopping` Status, sauberer Stop-Flow, Port-Wait vor "running" |

### Noch offen
- Keine. iframe-Embedding ist eliminiert.
