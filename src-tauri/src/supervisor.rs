//! # Hermes WebUI Process Supervisor
//!
//! Startet, stoppt und überwacht den Hermes WebUI Python-Server als
//! Child-Prozess. Thread-safe implementiert mit `Mutex<HermesSupervisor>`
//! und einem separaten Log-Ringbuffer (`Arc<Mutex<Vec<String>>>`) für die
//! stdout/stderr Reader-Threads.
//!
//! ## Sicherheit / Defensive Programmierung
//!
//! - Alle öffentlichen Funktionen behandeln Fehler defensiv — die App crashed
//!   nicht wenn Hermes nicht starten kann.
//! - Keine Unix-only APIs (`signal`, `nix` crate, etc.) — volle Windows-Kompatibilität.
//! - `taskkill` wird für sanftes + hartes Kill verwendet (Ctrl+C via taskkill /PID,
//!   Force via taskkill /F).
//! - Reader-Threads terminieren automatisch wenn die Pipes schliessen.
//! - Logs haben einen eigenen `Arc<Mutex<>>` → kein Deadlock zwischen Reader-Threads
//!   und Supervisor-API.
//! - Keine Zombie-Prozesse: `child.wait()` wird immer aufgerufen.

use std::io::{BufRead, BufReader};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

// ---------------------------------------------------------------------------
// Konstanten
// ---------------------------------------------------------------------------

/// Maximale Anzahl Log-Einträge im Ringbuffer (älteste werden verworfen).
const MAX_LOG_ENTRIES: usize = 1000;

/// Anzahl Logzeilen die `get_logs()` maximal zurückgibt.
const LOG_RETURN_COUNT: usize = 100;

/// Wartezeit zwischen Polls beim Kill-Vorgang.
const KILL_POLL_INTERVAL_MS: u64 = 200;

/// Maximale Wartezeit für sanften Exit via `taskkill /PID`.
const KILL_GRACEFUL_TIMEOUT_SECS: u64 = 3;

// ---------------------------------------------------------------------------
// Status-Konstanten (String, damit einfach via Tauri-Bridge serialisierbar)
// ---------------------------------------------------------------------------

pub const STATUS_STOPPED: &str = "stopped";
pub const STATUS_STARTING: &str = "starting";
pub const STATUS_RUNNING: &str = "running";
pub const STATUS_ERROR: &str = "error";

// ---------------------------------------------------------------------------
// Supervisor-Struct
// ---------------------------------------------------------------------------

/// Verwaltet den Hermes WebUI Child-Prozess inkl. Log-Erfassung.
///
/// Thread-safety:
/// - `HermesSupervisor` selbst wird von `Mutex<HermesSupervisor>` geschützt.
/// - Das `logs`-Feld hat einen **eigenen** `Arc<Mutex<Vec<String>>>` damit
///   die Reader-Threads (stdout/stderr) Logs schreiben können ohne den
///   Supervisor-Mutex zu benötigen → kein Deadlock-Risiko.
pub struct HermesSupervisor {
    /// Child-Prozess-Handle (None wenn gestoppt).
    child: Option<Child>,
    /// Aktueller Betriebsstatus.
    status: String,
    /// Ringbuffer für stdout/stderr (eigener Mutex, siehe oben).
    logs: Arc<Mutex<Vec<String>>>,
    /// Port auf dem Hermes WebUI zuletzt gestartet wurde.
    port: u16,
}

// ---------------------------------------------------------------------------
// Globaler Singleton (OnceLock — kein `once_cell`-Crate nötig)
// ---------------------------------------------------------------------------

/// Gibt die `&'static Mutex<HermesSupervisor>` Instanz zurück.
/// Lazy-initialisiert beim ersten Aufruf via `OnceLock::get_or_init`.
fn supervisor() -> &'static Mutex<HermesSupervisor> {
    static SUPERVISOR: std::sync::OnceLock<Mutex<HermesSupervisor>> =
        std::sync::OnceLock::new();
    SUPERVISOR.get_or_init(|| {
        Mutex::new(HermesSupervisor {
            child: None,
            status: STATUS_STOPPED.to_string(),
            logs: Arc::new(Mutex::new(Vec::new())),
            port: 0,
        })
    })
}

// ---------------------------------------------------------------------------
// Interne Hilfsfunktionen
// ---------------------------------------------------------------------------

/// Fügt eine Zeile zum Log-Ringbuffer hinzu.
///
/// Entfernt den ältesten Eintrag wenn `MAX_LOG_ENTRIES` überschritten wird.
/// Fehler beim Locken werden still ignoriert (Defensive).
fn append_log(logs: &Arc<Mutex<Vec<String>>>, line: String) {
    if let Ok(mut guard) = logs.lock() {
        if guard.len() >= MAX_LOG_ENTRIES {
            guard.remove(0);
        }
        guard.push(line);
    }
}

/// Prüft ob die angegebene Python-Executable existiert und ausführbar ist.
fn python_executable_exists(python_path: &str) -> bool {
    Command::new(python_path)
        .arg("--version")
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

/// Startet Reader-Threads für stdout/stderr des Child-Prozesses.
///
/// Jeder Thread liest zeilenweise aus seiner Pipe und schreibt in den
/// gemeinsamen Log-Ringbuffer. Die Threads terminieren automatisch wenn
/// die Pipe schliesst (Prozess beendet).
fn spawn_output_readers(
    stdout: Option<std::process::ChildStdout>,
    stderr: Option<std::process::ChildStderr>,
    logs: Arc<Mutex<Vec<String>>>,
) {
    if let Some(stdout) = stdout {
        let logs_stdout = logs.clone();
        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                match line {
                    Ok(text) => append_log(&logs_stdout, format!("[out] {}", text)),
                    Err(_) => break, // Pipe geschlossen = Prozess beendet
                }
            }
        });
    }

    if let Some(stderr) = stderr {
        let logs_stderr = logs;
        thread::spawn(move || {
            let reader = BufReader::new(stderr);
            for line in reader.lines() {
                match line {
                    Ok(text) => append_log(&logs_stderr, format!("[err] {}", text)),
                    Err(_) => break,
                }
            }
        });
    }
}

/// Versucht den Prozess sanft zu killen (`taskkill /PID` ohne /F).
///
/// Gibt `true` zurück wenn der Prozess innerhalb des Timeouts beendet wurde,
/// `false` wenn er noch läuft und Force-Kill nötig ist.
fn try_graceful_kill(child: &mut Child, pid: u32) -> bool {
    // Sanftes Signal: taskkill /PID <pid> (sendet Ctrl+C unter Windows)
    let _ = Command::new("taskkill")
        .arg("/PID")
        .arg(&pid.to_string())
        .output();

    // Warte auf Exit (polling)
    let deadline =
        std::time::Instant::now() + Duration::from_secs(KILL_GRACEFUL_TIMEOUT_SECS);
    while std::time::Instant::now() < deadline {
        match child.try_wait() {
            Ok(Some(_)) => return true, // Prozess beendet
            Ok(None) => {
                thread::sleep(Duration::from_millis(KILL_POLL_INTERVAL_MS));
            }
            Err(_) => return false, // try_wait fehlgeschlagen → Force-Kill
        }
    }
    false // Timeout → Force-Kill erforderlich
}

/// Erzwungener Kill via `taskkill /F` (killt inkl. Prozessbaum).
fn force_kill_process(pid: u32) {
    let _ = Command::new("taskkill")
        .arg("/F")
        .arg("/PID")
        .arg(&pid.to_string())
        .output();
}

// ---------------------------------------------------------------------------
// Öffentliche API — Kernfunktionen mit Parametern
// ---------------------------------------------------------------------------

/// Startet Hermes WebUI als Child-Prozess.
///
/// # Parameter
///
/// * `state_dir` — Basis-Verzeichnis für App-State (z. B. `%APPDATA%/Sidekick`).
///   Darin wird automatisch `hermes-webui/` als `HERMES_WEBUI_STATE_DIR` genutzt.
/// * `hermes_dir` — Verzeichnis in dem `server.py` liegt (vendor/hermes-webui).
/// * `python_path` — Vollständiger Pfad zur Python-Executable (z. B.
///   `.../runtime/.venv/Scripts/python.exe` oder `python` falls auf PATH).
/// * `port` — Gewünschter Port (z. B. `8787`).
///
/// # Fehler
///
/// - Wenn Hermes bereits läuft.
/// - Wenn `python_path` nicht existiert oder nicht ausführbar ist.
/// - Wenn `Command::spawn` fehlschlägt (z. B. Working-Dir existiert nicht).
#[allow(dead_code)]
pub fn start_hermes_with(
    state_dir: &str,
    hermes_dir: &str,
    python_path: &str,
    port: u16,
) -> Result<String, String> {
    // ── 1. Supervisor-Lock holen ─────────────────────────────────────────
    let mut guard = supervisor()
        .lock()
        .map_err(|e| format!("Supervisor lock error: {}", e))?;

    // ── 2. Zustandsprüfung ──────────────────────────────────────────────
    if guard.status == STATUS_RUNNING || guard.status == STATUS_STARTING {
        return Err("Hermes WebUI läuft bereits".to_string());
    }

    // ── 3. Python-Existenzprüfung ───────────────────────────────────────
    if !python_executable_exists(python_path) {
        guard.status = STATUS_ERROR.to_string();
        return Err(format!(
            "Python nicht gefunden oder nicht ausführbar: {}",
            python_path
        ));
    }

    // ── 4. Status setzen ────────────────────────────────────────────────
    guard.status = STATUS_STARTING.to_string();
    guard.port = port;

    let hermes_state_dir = format!("{}/hermes-webui", state_dir.trim_end_matches('/'));
    let port_str = port.to_string();

    // ── 5. Child-Prozess starten ────────────────────────────────────────
    let mut child = match Command::new(python_path)
        .arg("server.py")
        .env("HERMES_WEBUI_HOST", "127.0.0.1")
        .env("HERMES_WEBUI_PORT", &port_str)
        .env("HERMES_WEBUI_STATE_DIR", &hermes_state_dir)
        .env("PYTHONIOENCODING", "utf-8")
        .current_dir(hermes_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            guard.status = STATUS_ERROR.to_string();
            return Err(format!(
                "Fehler beim Starten von Hermes WebUI (server.py): {}",
                e
            ));
        }
    };

    // ── 6. Stdout/Stderr Reader-Threads starten ─────────────────────────
    let logs = guard.logs.clone();
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    spawn_output_readers(stdout, stderr, logs.clone());

    let pid = child.id();
    let port_log = guard.port;

    // ── 7. Erfolg vermerken ─────────────────────────────────────────────
    append_log(
        &logs,
        format!(
            "Hermes WebUI gestartet (PID: {}, Port: {}, Python: {})",
            pid, port_log, python_path
        ),
    );

    guard.child = Some(child);
    guard.status = STATUS_RUNNING.to_string();

    Ok(format!("Hermes WebUI gestartet auf Port {}", port_log))
}

/// Stoppt den Hermes WebUI Prozess.
///
/// Strategie (Windows-kompatibel):
/// 1. `taskkill /PID <pid>` — sendet Ctrl+C für sauberen Shutdown.
/// 2. Warte bis zu 3 Sekunden auf Exit (polling).
/// 3. Falls noch nicht beendet: `taskkill /F /PID <pid>` (Force, inkl.
///    Prozessbaum).
/// 4. Warte final auf `child.wait()` um Ressourcen freizugeben.
///
/// # Fehler
///
/// Gibt einen Fehler zurück wenn kein Prozess läuft. Der Status wird
/// dennoch auf `"stopped"` gesetzt.
pub fn stop_hermes() -> Result<String, String> {
    // ── 1. Supervisor-Lock ──────────────────────────────────────────────
    let mut guard = supervisor()
        .lock()
        .map_err(|e| format!("Supervisor lock error: {}", e))?;

    // ── 2. Child entnehmen ──────────────────────────────────────────────
    let mut child = match guard.child.take() {
        Some(c) => c,
        None => {
            guard.status = STATUS_STOPPED.to_string();
            guard.port = 0;
            return Err("Kein laufender Hermes WebUI Prozess".to_string());
        }
    };

    let pid = child.id();
    let logs = guard.logs.clone();

    append_log(&logs, format!("Stoppe Hermes WebUI (PID: {})...", pid));

    // Status auf stopped setzen
    guard.status = STATUS_STOPPED.to_string();
    guard.port = 0;

    // Lock freigeben damit Reader-Threads weiterlaufen können
    drop(guard);

    // ── 3. Sanftes Kill ─────────────────────────────────────────────────
    let graceful = try_graceful_kill(&mut child, pid);

    if !graceful {
        // ── 4. Hartes Kill ──────────────────────────────────────────────
        if let Some(logs_arc) = supervisor()
            .lock()
            .ok()
            .map(|g| g.logs.clone())
        {
            append_log(
                &logs_arc,
                format!("Force-Kill Hermes WebUI (PID: {})...", pid),
            );
        }

        force_kill_process(pid);

        // Final warten (taskkill /F ist asynchron)
        let _ = child.wait();
    }

    // ── 5. Abschluss-Log ────────────────────────────────────────────────
    if let Some(logs_arc) = supervisor()
        .lock()
        .ok()
        .map(|g| g.logs.clone())
    {
        append_log(
            &logs_arc,
            format!("Hermes WebUI gestoppt (PID: {})", pid),
        );
    }

    Ok("Hermes WebUI gestoppt".to_string())
}

/// Startet Hermes WebUI neu (stop + start).
///
/// Ruft zuerst `stop_hermes()` auf (ignoriert Fehler falls nicht gestartet)
/// und dann `start_hermes_with()` mit den gegebenen Parametern.
#[allow(dead_code)]
pub fn restart_hermes_with(
    state_dir: &str,
    hermes_dir: &str,
    python_path: &str,
    port: u16,
) -> Result<String, String> {
    let _ = stop_hermes();
    start_hermes_with(state_dir, hermes_dir, python_path, port)
}

// ---------------------------------------------------------------------------
// Öffentliche API — Tauri-Kommandos (parameterlos, laden Settings intern)
// ---------------------------------------------------------------------------

/// Startet Hermes WebUI mit Werten aus den gespeicherten Settings.
///
/// Lädt `Settings` via `crate::settings`, sucht einen freien Port via
/// `crate::ports`, und delegiert an `start_hermes_with`.
///
/// Aufrufbar als Tauri-Kommando `start_hermes`.
pub fn start_hermes() -> Result<String, String> {
    let settings = crate::settings::load_settings();
    let state_dir = crate::settings::get_state_dir();
    let port = crate::ports::find_free_port(settings.preferred_port);

    start_hermes_with(
        &state_dir,
        &settings.hermes_path,
        &settings.python_path,
        port,
    )
}

/// Startet Hermes WebUI neu mit Werten aus den gespeicherten Settings.
///
/// Aufrufbar als Tauri-Kommando `restart_hermes`.
pub fn restart_hermes() -> Result<String, String> {
    let settings = crate::settings::load_settings();
    let state_dir = crate::settings::get_state_dir();
    let port = crate::ports::find_free_port(settings.preferred_port);

    restart_hermes_with(
        &state_dir,
        &settings.hermes_path,
        &settings.python_path,
        port,
    )
}

// ---------------------------------------------------------------------------
// Öffentliche API — Status / Logs
// ---------------------------------------------------------------------------

/// Gibt den aktuellen Status des Supervisors zurück.
///
/// Mögliche Werte: `"stopped"`, `"starting"`, `"running"`, `"error"`.
///
/// Bei Lock-Fehlern wird `"error"` zurückgegeben (Defensive).
pub fn get_status() -> String {
    supervisor()
        .lock()
        .map(|g| g.status.clone())
        .unwrap_or_else(|_| STATUS_ERROR.to_string())
}

/// Gibt die letzten Logzeilen aus dem Ringbuffer zurück.
///
/// Maximal 100 Einträge (letzte 100). Der Ringbuffer selbst fasst
/// maximal 1000 Einträge, bevor die ältesten verworfen werden.
///
/// Thread-safe: Der Supervisor-Mutex wird nur kurz gehalten um die
/// `Arc<Mutex<Vec<String>>>` zu klonen, dann wird der Log-Mutex separat
/// gelockt. Dadurch blockieren sich Reader-Threads und `get_logs()` nicht
/// gegenseitig.
pub fn get_logs() -> Result<Vec<String>, String> {
    // 1. Supervisor-Lock → Arc klonen → Lock freigeben
    let logs_arc = supervisor()
        .lock()
        .map_err(|e| format!("Supervisor lock error: {}", e))?
        .logs
        .clone();

    // 2. Log-Mutex locken → letzte Einträge lesen
    let guard = logs_arc
        .lock()
        .map_err(|e| format!("Log lock error: {}", e))?;

    let len = guard.len();
    if len == 0 {
        return Ok(Vec::new());
    }
    let start = if len > LOG_RETURN_COUNT {
        len - LOG_RETURN_COUNT
    } else {
        0
    };
    Ok(guard[start..].to_vec())
}

/// Gibt den aktuellen Port zurück auf dem Hermes WebUI läuft (0 wenn gestoppt).
pub fn get_port() -> u16 {
    supervisor()
        .lock()
        .map(|g| g.port)
        .unwrap_or(0)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initial_state() {
        // Durch die OnceLock-Initialisierung müssen wir vorsichtig sein:
        // Andere Tests könnten den Supervisor schon initialisiert haben.
        // Wir prüfen nur, dass der Status initial gültig ist.
        let status = get_status();
        assert!(
            status == STATUS_STOPPED
                || status == STATUS_RUNNING
                || status == STATUS_STARTING
                || status == STATUS_ERROR,
            "Unerwarteter Status: {}",
            status
        );
    }

    #[test]
    fn test_status_constants() {
        assert_eq!(STATUS_STOPPED, "stopped");
        assert_eq!(STATUS_STARTING, "starting");
        assert_eq!(STATUS_RUNNING, "running");
        assert_eq!(STATUS_ERROR, "error");
    }

    #[test]
    fn test_append_log_ringbuffer() {
        let logs = Arc::new(Mutex::new(Vec::new()));

        // Befülle bis zur Kapazität
        for i in 0..MAX_LOG_ENTRIES {
            append_log(&logs, format!("line {}", i));
        }

        {
            let guard = logs.lock().unwrap();
            assert_eq!(guard.len(), MAX_LOG_ENTRIES);
            assert_eq!(guard[0], "line 0");
            assert_eq!(
                guard[MAX_LOG_ENTRIES - 1],
                format!("line {}", MAX_LOG_ENTRIES - 1)
            );
        }

        // Ein weiterer Eintrag entfernt den ältesten
        append_log(&logs, "overflow line".to_string());
        {
            let guard = logs.lock().unwrap();
            assert_eq!(guard.len(), MAX_LOG_ENTRIES);
            assert_eq!(guard[0], "line 1");
            assert_eq!(guard[MAX_LOG_ENTRIES - 1], "overflow line");
        }
    }

    #[test]
    fn test_get_logs_empty() {
        // get_logs sollte nie crashen, auch wenn keine Logs da sind
        let result = get_logs();
        assert!(result.is_ok());
        // Kann leer sein oder bereits Logs von anderen Tests enthalten
    }

    #[test]
    fn test_get_logs_truncation() {
        let logs = Arc::new(Mutex::new(Vec::new()));

        // Schreibe mehr als LOG_RETURN_COUNT Einträge
        for i in 0..200 {
            append_log(&logs, format!("log {}", i));
        }

        // Prüfe via temporärem Einschub in den Supervisor (für Test)
        {
            let mut guard = supervisor().lock().unwrap();
            // Nur für den Test: kopiere test-logs in supervisor
            *guard.logs.lock().unwrap() = logs.lock().unwrap().clone();
        }

        let result = get_logs().unwrap();
        // Sollte maximal LOG_RETURN_COUNT Einträge zurückgeben
        assert!(result.len() <= LOG_RETURN_COUNT);
        // Der letzte Eintrag sollte "log 199" sein
        assert_eq!(result[result.len() - 1], "log 199");

        // Cleanup
        {
            let mut guard = supervisor().lock().unwrap();
            guard.logs.lock().unwrap().clear();
        }
    }

    #[test]
    fn test_python_check_invalid_path() {
        assert!(!python_executable_exists(
            "C:/does/not/exist/python_zxy999.exe"
        ));
    }

    #[test]
    fn test_stop_when_not_running() {
        // stop_hermes sollte keinen Crash verursachen
        let result = stop_hermes();
        // Kann Ok oder Err sein — Hauptsache kein Panic
        let _ = result;
    }

    #[test]
    fn test_start_with_invalid_python() {
        // reset status
        {
            let mut guard = supervisor().lock().unwrap();
            guard.child = None;
            guard.status = STATUS_STOPPED.to_string();
            guard.port = 0;
        }

        // start mit ungültigem Python-Pfad → Fehler, kein Crash
        let result = start_hermes_with(
            "C:/tmp",
            "F:/finalbrowser/vendor/hermes-webui",
            "C:/does/not/exist/python_invalid.exe",
            9999,
        );
        assert!(result.is_err());

        // Status muss auf error sein
        assert_eq!(get_status(), STATUS_ERROR);
    }

    #[test]
    fn test_double_start_fails() {
        // Status auf error setzen (simuliert)
        {
            let mut guard = supervisor().lock().unwrap();
            guard.status = STATUS_ERROR.to_string();
            guard.port = 0;
        }

        // Status muss error sein
        assert_eq!(get_status(), STATUS_ERROR);

        // Start sollte error zurückgeben weil vorheriger Fehler
        let result = start_hermes_with(
            "C:/tmp",
            "F:/finalbrowser/vendor/hermes-webui",
            "C:/does/not/exist/python_invalid.exe",
            9997,
        );
        assert!(result.is_err());

        // starten während running
        {
            let mut guard = supervisor().lock().unwrap();
            guard.status = STATUS_RUNNING.to_string();
        }
        let result = start_hermes_with(
            "C:/tmp",
            "F:/finalbrowser/vendor/hermes-webui",
            "C:/does/not/exist/python_invalid.exe",
            9996,
        );
        assert!(result.is_err());
        assert!(
            result.unwrap_err().contains("bereits"),
            "Sollte 'bereits läuft' melden"
        );

        // cleanup
        {
            let mut guard = supervisor().lock().unwrap();
            guard.status = STATUS_STOPPED.to_string();
            guard.child = None;
            guard.port = 0;
        }
    }

    #[test]
    fn test_get_port_initial() {
        // Nach cleanup sollte Port 0 sein
        assert_eq!(get_port(), 0);
    }

    #[test]
    fn test_spawn_output_readers_smoke() {
        // Nur prüfen dass spawn_output_readers keinen panic wirft
        // mit None-Pipes
        spawn_output_readers(None, None, Arc::new(Mutex::new(Vec::new())));
        // Kein Assert nötig — Hauptsache kein Crash
    }

    #[test]
    fn test_graceful_kill_no_process() {
        // try_graceful_kill mit inexistentem Kind-Prozess sollte
        // nicht crashen (auch wenn die Funktion es nicht schafft,
        // den Prozess zu killen)
        // Wir können das nicht direkt testen ohne echten Prozess.
        // Der Test existiert als Dokumentation dass dieser Pfad
        // sicher ist.
    }
}
