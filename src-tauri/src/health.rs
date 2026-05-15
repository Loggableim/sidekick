use std::time::{Duration, Instant};

/// Represents the health status of the Hermes WebUI backend.
#[derive(Debug, Clone, PartialEq)]
pub enum HealthStatus {
    /// The backend returned `{"status": "ok"}` – it is fully operational.
    Ok,
    /// The backend is not yet reachable or still starting up.
    Starting,
    /// The backend responded but the health check failed with the given message.
    Error(String),
}

/// Poll `http://127.0.0.1:{port}/health` until a response is received or
/// `timeout_secs` elapses.
///
/// Polling interval: every 500 ms.
///
/// Return values:
/// - `Ok(HealthStatus::Ok)` – the backend returned `{"status": "ok"}`.
/// - `Ok(HealthStatus::Starting)` – no successful response within the timeout,
///   or connection refused / reset during the polling window.
/// - `Ok(HealthStatus::Error(msg))` – the backend responded but the JSON was
///   malformed or the status field was not `"ok"`.
/// - `Err(msg)` – an unrecoverable error occurred (e.g. the reqwest client
///   failed to initialise).
pub fn check_health(port: u16, timeout_secs: u64) -> Result<HealthStatus, String> {
    let url = format!("http://127.0.0.1:{}/health", port);
    let timeout = Duration::from_secs(timeout_secs);
    let poll_interval = Duration::from_millis(500);
    let deadline = Instant::now() + timeout;

    // Build the client once (avoids repeated TLS/connector setup)
    let client = reqwest::blocking::Client::builder()
        .timeout(poll_interval) // per-request timeout matches the poll interval
        .build()
        .map_err(|e| format!("Failed to build HTTP client: {}", e))?;

    loop {
        let now = Instant::now();
        if now >= deadline {
            // Timeout reached – the backend is still starting
            return Ok(HealthStatus::Starting);
        }

        let remaining = deadline - now;
        let request_timeout = std::cmp::min(poll_interval, remaining);

        // Update the client timeout for this request
        let client = reqwest::blocking::Client::builder()
            .timeout(request_timeout)
            .build()
            .map_err(|e| format!("Failed to build HTTP client: {}", e))?;

        match client.get(&url).send() {
            Ok(response) => {
                // We got a response – try to parse it
                match response.json::<serde_json::Value>() {
                    Ok(json) => {
                        match json.get("status").and_then(|v| v.as_str()) {
                            Some("ok") => return Ok(HealthStatus::Ok),
                            Some(other) => {
                                return Ok(HealthStatus::Error(format!(
                                    "Unexpected status: '{}'",
                                    other
                                )));
                            }
                            None => {
                                return Ok(HealthStatus::Error(
                                    "Response JSON missing 'status' field".to_string(),
                                ));
                            }
                        }
                    }
                    Err(e) => {
                        // JSON parse error – treat as an error response
                        return Ok(HealthStatus::Error(format!(
                            "Failed to parse health response: {}",
                            e
                        )));
                    }
                }
            }
            Err(e) => {
                // Connection-level error – the server may not be ready yet
                // We sleep and retry (unless we've passed the deadline, which
                // is checked at the top of the loop).
                if now + poll_interval >= deadline {
                    // Not enough time for another full poll cycle
                    return Ok(HealthStatus::Starting);
                }
                std::thread::sleep(poll_interval);
                // Continue the loop
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Calling `check_health` on a port where nothing is listening should
    /// eventually time out and return `Starting`.
    #[test]
    fn test_check_health_no_server() {
        // Port 1 is never available on any sane system
        let result = check_health(1, 2);
        match result {
            Ok(HealthStatus::Starting) => {} // expected
            Ok(other) => panic!("Expected Starting, got {:?}", other),
            Err(e) => panic!("Unexpected error: {}", e),
        }
    }

    #[test]
    fn test_health_status_debug() {
        let status = HealthStatus::Ok;
        assert_eq!(format!("{:?}", status), "Ok");

        let status = HealthStatus::Starting;
        assert_eq!(format!("{:?}", status), "Starting");

        let status = HealthStatus::Error("something went wrong".into());
        assert!(format!("{:?}", status).contains("something went wrong"));
    }

    #[test]
    fn test_health_status_clone_and_eq() {
        let a = HealthStatus::Ok;
        let b = HealthStatus::Ok;
        assert_eq!(a, b);

        let c = HealthStatus::Starting;
        assert_ne!(a, c);

        let d = HealthStatus::Error("x".into());
        let e = HealthStatus::Error("x".into());
        assert_eq!(d, e);

        let f = HealthStatus::Error("y".into());
        assert_ne!(d, f);
    }
}
