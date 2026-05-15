use serde::{Deserialize, Serialize};
use std::path::PathBuf;

// ---------------------------------------------------------------------------
// Settings struct – persisted as JSON in %APPDATA%\Sidekick\config\settings.json
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Settings {
    /// Path to vendor/hermes-webui directory.
    /// Default: resolved relative to the running executable.
    pub hermes_path: String,

    /// Python interpreter command (must be on PATH or an absolute path).
    pub python_path: String,

    /// Preferred port for the Hermes WebUI.
    pub preferred_port: u16,

    /// Automatically start Hermes when the app launches.
    pub auto_start: bool,

    /// Automatically restart Hermes if it crashes.
    pub auto_restart: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            hermes_path: default_hermes_path(),
            python_path: "python".to_string(),
            preferred_port: 8787,
            auto_start: false,
            auto_restart: false,
        }
    }
}

// ---------------------------------------------------------------------------
// AppData directory helpers
// ---------------------------------------------------------------------------

/// Returns the base Sidekick directory under %APPDATA%.
///
/// Example: `C:\Users\<user>\AppData\Roaming\Sidekick`
fn appdata_dir() -> PathBuf {
    let appdata = std::env::var("APPDATA")
        .expect("APPDATA environment variable is not set");
    PathBuf::from(appdata).join("Sidekick")
}

/// Returns `%APPDATA%\Sidekick`
pub fn get_appdata_dir() -> String {
    to_windows_path(appdata_dir())
}

/// Returns `%APPDATA%\Sidekick\state`
pub fn get_state_dir() -> String {
    to_windows_path(appdata_dir().join("state"))
}

/// Returns `%APPDATA%\Sidekick\logs`
pub fn get_logs_dir() -> String {
    to_windows_path(appdata_dir().join("logs"))
}

/// Returns `%APPDATA%\Sidekick\config`
pub fn get_config_dir() -> String {
    to_windows_path(appdata_dir().join("config"))
}

/// Returns `%APPDATA%\Sidekick\runtime`
pub fn get_runtime_dir() -> String {
    to_windows_path(appdata_dir().join("runtime"))
}

// ---------------------------------------------------------------------------
// Settings persistence
// ---------------------------------------------------------------------------

/// Path to the JSON settings file.
fn settings_file_path() -> PathBuf {
    appdata_dir().join("config").join("settings.json")
}

/// Load settings from disk.
///
/// If the config file does not exist, default settings are returned.
/// If the file is corrupted or unreadable, defaults are returned silently.
pub fn load_settings() -> Settings {
    let path = settings_file_path();

    if !path.exists() {
        return Settings::default();
    }

    match std::fs::read_to_string(&path) {
        Ok(content) => match serde_json::from_str::<Settings>(&content) {
            Ok(settings) => settings,
            Err(_) => {
                // Config file is corrupted – fall back to defaults
                Settings::default()
            }
        },
        Err(_) => Settings::default(),
    }
}

/// Save settings to disk.
///
/// The config directory is created if it does not exist.
pub fn save_settings(settings: &Settings) -> Result<(), String> {
    let path = settings_file_path();

    // Ensure the config directory exists
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create config directory: {}", e))?;
    }

    let content = serde_json::to_string_pretty(settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;

    std::fs::write(&path, content)
        .map_err(|e| format!("Failed to write settings file: {}", e))?;

    Ok(())
}

/// Ensure all Sidekick AppData directories exist (creating them if necessary).
pub fn ensure_dirs() -> Result<(), String> {
    let dirs = [
        get_appdata_dir(),
        get_state_dir(),
        get_logs_dir(),
        get_config_dir(),
        get_runtime_dir(),
    ];

    for dir in &dirs {
        std::fs::create_dir_all(dir)
            .map_err(|e| format!("Failed to create directory '{}': {}", dir, e))?;
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Convert a `PathBuf` to a Windows-style backslash path string.
fn to_windows_path(path: PathBuf) -> String {
    path.to_string_lossy().replace('/', "\\")
}

/// Compute the default `hermes_path`:
///
/// 1. Try to resolve `../vendor/hermes-webui` relative to the executable
///    directory (as specified by "relativ zum EXE-Pfad").
/// 2. If that fails, walk up the directory tree looking for a `vendor/hermes-webui`
///    directory.
/// 3. As a last resort, return the literal relative path `..\\vendor\\hermes-webui`.
fn default_hermes_path() -> String {
    // Strategy 1: resolve ../vendor/hermes-webui relative to the exe dir
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(exe_dir) = exe_path.parent() {
            let candidate = exe_dir.join("..").join("vendor").join("hermes-webui");
            if let Ok(canonical) = candidate.canonicalize() {
                return to_windows_path(canonical);
            }

            // Strategy 2: walk up the tree
            let mut current = Some(exe_dir);
            while let Some(dir) = current {
                let test = dir.join("vendor").join("hermes-webui");
                if test.is_dir() {
                    return to_windows_path(test);
                }
                current = dir.parent();
            }
        }
    }

    // Strategy 3: fallback relative path
    let fallback = PathBuf::from("..\\vendor\\hermes-webui");
    if let Ok(canonical) = fallback.canonicalize() {
        return to_windows_path(canonical);
    }

    "..\\vendor\\hermes-webui".to_string()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_settings() {
        let s = Settings::default();
        assert_eq!(s.python_path, "python");
        assert_eq!(s.preferred_port, 8787);
        assert!(!s.auto_start);
        assert!(!s.auto_restart);
        // hermes_path should not be empty
        assert!(!s.hermes_path.is_empty());
    }

    #[test]
    fn test_to_windows_path() {
        let path = PathBuf::from("C:/Users/test/Sidekick");
        assert_eq!(to_windows_path(path), "C:\\Users\\test\\Sidekick");
    }

    #[test]
    fn test_get_appdata_dir_contains_sidekick() {
        let dir = get_appdata_dir();
        assert!(dir.contains("Sidekick"));
    }

    #[test]
    fn test_get_state_dir_ends_with_state() {
        let dir = get_state_dir();
        assert!(dir.ends_with("state") || dir.ends_with("state\\"));
    }

    #[test]
    fn test_get_logs_dir_ends_with_logs() {
        let dir = get_logs_dir();
        assert!(dir.ends_with("logs") || dir.ends_with("logs\\"));
    }

    #[test]
    fn test_get_config_dir_ends_with_config() {
        let dir = get_config_dir();
        assert!(dir.ends_with("config") || dir.ends_with("config\\"));
    }

    #[test]
    fn test_get_runtime_dir_ends_with_runtime() {
        let dir = get_runtime_dir();
        assert!(dir.ends_with("runtime") || dir.ends_with("runtime\\"));
    }

    #[test]
    fn test_save_and_load_settings() {
        let settings = Settings {
            hermes_path: "C:\\vendor\\hermes-webui".to_string(),
            python_path: "python3".to_string(),
            preferred_port: 9999,
            auto_start: true,
            auto_restart: true,
        };

        // Save
        assert!(save_settings(&settings).is_ok());

        // Load
        let loaded = load_settings();
        assert_eq!(loaded.hermes_path, "C:\\vendor\\hermes-webui");
        assert_eq!(loaded.python_path, "python3");
        assert_eq!(loaded.preferred_port, 9999);
        assert!(loaded.auto_start);
        assert!(loaded.auto_restart);
    }

    #[test]
    fn test_ensure_dirs() {
        assert!(ensure_dirs().is_ok());

        // Verify directories exist
        let dirs = [
            get_appdata_dir(),
            get_state_dir(),
            get_logs_dir(),
            get_config_dir(),
            get_runtime_dir(),
        ];
        for dir in &dirs {
            let path = PathBuf::from(dir);
            assert!(path.is_dir(), "Directory does not exist: {}", dir);
        }
    }

    #[test]
    fn test_load_settings_non_existent_returns_defaults() {
        // Temporarily move/rename any existing settings file
        let path = settings_file_path();
        let backup = if path.exists() {
            let backup_path = path.with_extension("json.bak");
            std::fs::rename(&path, &backup_path).ok();
            Some(backup_path)
        } else {
            None
        };

        let settings = load_settings();
        assert_eq!(settings.preferred_port, 8787);

        // Restore backup
        if let Some(backup_path) = backup {
            std::fs::rename(&backup_path, &path).ok();
        }
    }
}
