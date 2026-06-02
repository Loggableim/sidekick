// Sidekick — Tauri 2 Desktop App
// Windows-Desktop-App mit WebView2, die Sidekick als Sidecar startet.

mod supervisor;
mod settings;
mod ports;

use std::process::Command;
use std::path::Path;
use tauri::Manager;

// ---------------------------------------------------------------------------
// Tauri 2 Commands
// ---------------------------------------------------------------------------

/// Startet den Sidekick-Prozess über den Supervisor.
#[tauri::command]
fn start_sidekick() -> Result<String, String> {
    supervisor::start_sidekick().map_err(|e| e.to_string())
}

/// Stoppt den Sidekick-Prozess.
#[tauri::command]
fn stop_sidekick() -> Result<String, String> {
    supervisor::stop_sidekick().map_err(|e| e.to_string())
}

/// Startet den Sidekick-Prozess neu (stop + start).
#[tauri::command]
fn restart_sidekick() -> Result<String, String> {
    supervisor::restart_sidekick().map_err(|e| e.to_string())
}

/// Gibt den aktuellen Status des Sidekick-Prozesses zurück.
#[tauri::command]
fn get_status() -> String {
    supervisor::get_status()
}

/// Gibt die aktuellen Logs des Sidekick-Prozesses zurück.
#[tauri::command]
fn get_logs() -> Result<Vec<String>, String> {
    supervisor::get_logs().map_err(|e| e.to_string())
}

/// Öffnet den AppData-Ordner (%APPDATA%/Sidekick) im Windows Explorer.
#[tauri::command]
fn open_appdata() -> Result<(), String> {
    let appdata = std::env::var("APPDATA")
        .map_err(|_| "APPDATA-Umgebungsvariable nicht gefunden".to_string())?;
    let path = Path::new(&appdata).join("Sidekick");
    let _ = std::fs::create_dir_all(&path);
    Command::new("explorer")
        .arg(path.to_str().ok_or("Ungültiger Pfad")?)
        .spawn()
        .map_err(|e| format!("Explorer konnte nicht gestartet werden: {}", e))?;
    Ok(())
}

/// Öffnet die Sidekick WebUI im Standard-Browser.
#[tauri::command]
fn open_external_browser(port: u16) -> Result<(), String> {
    let url = format!("http://localhost:{}", port);
    Command::new("cmd")
        .args(["/c", "start", "", &url])
        .spawn()
        .map_err(|e| format!("Browser konnte nicht geöffnet werden: {}", e))?;
    Ok(())
}

/// Öffnet Sidekick in einem eigenen nativen Tauri WebviewWindow.
/// Wenn bereits ein Fenster mit Label "sidekick-webui" existiert, wird es
/// fokussiert statt ein neues zu öffnen.
#[tauri::command]
fn open_sidekick_window(app: tauri::AppHandle, port: u16) -> Result<(), String> {
    let status = supervisor::get_status();
    if status != supervisor::STATUS_RUNNING {
        return Err("Sidekick ist nicht gestartet".to_string());
    }

    let url = format!("http://127.0.0.1:{}/", port);
    let parsed_url = url.parse::<tauri::Url>()
        .map_err(|e| format!("Ungültige URL: {}", e))?;

    // Prüfen ob Fenster bereits existiert -> fokussieren
    if let Some(window) = app.get_webview_window("sidekick-webui") {
        window.set_focus().map_err(|e| format!("Fokussieren fehlgeschlagen: {}", e))?;
        return Ok(());
    }

    // Neues WebviewWindow erstellen
    tauri::WebviewWindowBuilder::new(
        &app,
        "sidekick-webui",
        tauri::WebviewUrl::External(parsed_url),
    )
    .title("Sidekick")
    .inner_size(1200.0, 800.0)
    .resizable(true)
    .build()
    .map_err(|e| format!("WebviewWindow konnte nicht erstellt werden: {}", e))?;

    Ok(())
}

/// Schliesst das Sidekick-Fenster, falls es offen ist.
#[tauri::command]
fn close_sidekick_window(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("sidekick-webui") {
        window.close().map_err(|e| format!("Schliessen fehlgeschlagen: {}", e))?;
    }
    Ok(())
}

/// Lädt die aktuellen Sidekick-Einstellungen.
#[tauri::command]
fn get_settings() -> settings::Settings {
    settings::load_settings()
}

/// Speichert die Sidekick-Einstellungen.
#[tauri::command]
fn save_settings(settings_data: settings::Settings) -> Result<(), String> {
    settings::save_settings(&settings_data)
}

// ---------------------------------------------------------------------------
// App-Einstiegspunkt
// ---------------------------------------------------------------------------

fn main() {
    tauri::Builder::default()
        .setup(|_app| {
            // AppData-Verzeichnisse beim Start anlegen
            let _ = settings::ensure_dirs();
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            start_sidekick,
            stop_sidekick,
            restart_sidekick,
            get_status,
            get_logs,
            open_appdata,
            open_external_browser,
            open_sidekick_window,
            close_sidekick_window,
            get_settings,
            save_settings,
        ])
        .run(tauri::generate_context!())
        .expect("Fehler beim Starten der Sidekick-App");
}
