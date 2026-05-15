// Sidekick — Tauri 2 Desktop App
// Windows-Desktop-App mit WebView2, die Hermes WebUI als Sidecar startet.

// Module declarations — implemented in separate files (will be created later)
mod supervisor;
mod settings;
mod ports;
mod health;

use std::process::Command;
use std::path::Path;

// ---------------------------------------------------------------------------
// Tauri 2 Commands
// ---------------------------------------------------------------------------

/// Startet den Hermes WebUI-Prozess über den Supervisor.
#[tauri::command]
fn start_hermes() -> Result<String, String> {
    supervisor::start_hermes().map_err(|e| e.to_string())
}

/// Stoppt den Hermes WebUI-Prozess.
#[tauri::command]
fn stop_hermes() -> Result<String, String> {
    supervisor::stop_hermes().map_err(|e| e.to_string())
}

/// Startet den Hermes WebUI-Prozess neu (stop + start).
#[tauri::command]
fn restart_hermes() -> Result<String, String> {
    supervisor::restart_hermes().map_err(|e| e.to_string())
}

/// Gibt den aktuellen Status des Hermes-Prozesses zurück.
/// Rückgabe: "starting", "running", "error" oder "stopped"
#[tauri::command]
fn get_status() -> String {
    supervisor::get_status()
}

/// Gibt die aktuellen Logs des Hermes-Prozesses zurück.
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

    // Ordner erstellen falls nicht vorhanden
    let _ = std::fs::create_dir_all(&path);

    Command::new("explorer")
        .arg(path.to_str().ok_or("Ungültiger Pfad")?)
        .spawn()
        .map_err(|e| format!("Explorer konnte nicht gestartet werden: {}", e))?;

    Ok(())
}

/// Öffnet die Hermes WebUI im Standard-Browser.
#[tauri::command]
fn open_browser(port: u16) -> Result<(), String> {
    let url = format!("http://localhost:{}", port);

    Command::new("cmd")
        .args(["/c", "start", "", &url])
        .spawn()
        .map_err(|e| format!("Browser konnte nicht geöffnet werden: {}", e))?;

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
        .invoke_handler(tauri::generate_handler![
            start_hermes,
            stop_hermes,
            restart_hermes,
            get_status,
            get_logs,
            open_appdata,
            open_browser,
            get_settings,
            save_settings,
        ])
        .run(tauri::generate_context!())
        .expect("Fehler beim Starten der Sidekick-App");
}
