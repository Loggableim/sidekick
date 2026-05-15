use std::net::TcpListener;

/// Find a free TCP port starting from `preferred`.
///
/// Strategy:
/// 1. Try `preferred` (default: 8787).
/// 2. If taken, try `preferred + 1` (8788), then `preferred + 2` (8789).
/// 3. If all three are taken, scan upwards from 8790 until a free port is found.
///
/// All probes bind to `127.0.0.1`.
/// The function always returns a port number – it will panic only if the OS
/// runs out of ephemeral ports entirely (extremely unlikely).
pub fn find_free_port(preferred: u16) -> u16 {
    // 1. Try the preferred port
    if is_port_free(preferred) {
        return preferred;
    }

    // 2. Try preferred + 1, preferred + 2
    for offset in 1..=2 {
        let candidate = preferred.saturating_add(offset);
        if candidate != 0 && is_port_free(candidate) {
            return candidate;
        }
    }

    // 3. Scan from 8790 upwards
    let start = u16::max(preferred.saturating_add(3), 8790);
    for candidate in start..u16::MAX {
        if is_port_free(candidate) {
            return candidate;
        }
    }

    // 4. Last resort – 0 means "OS picks a free port"
    // This should never fail on any sane system
    match TcpListener::bind("127.0.0.1:0") {
        Ok(listener) => {
            let port = listener.local_addr().unwrap().port();
            // Drop the listener so the port is free again
            drop(listener);
            port
        }
        Err(_) => {
            // Truly catastrophic – panic so the caller knows something is broken
            panic!("No free TCP port found on 127.0.0.1");
        }
    }
}

/// Return `true` if `127.0.0.1:{port}` is available for binding.
fn is_port_free(port: u16) -> bool {
    match TcpListener::bind(("127.0.0.1", port)) {
        Ok(listener) => {
            // We successfully bound – release the port immediately
            drop(listener);
            true
        }
        Err(_) => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_free_port_default_preferred() {
        let port = find_free_port(8787);
        // Should always return a port between 8787 and some reasonable range
        assert!(port >= 8787, "Port should be >= 8787, got {}", port);
    }

    #[test]
    fn test_is_port_free_on_known_free() {
        // Find a free port first, then verify it's reported as free
        let port = find_free_port(9000);
        assert!(is_port_free(port), "Port {} should be free", port);
    }

    #[test]
    fn test_is_port_free_on_bound_port() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();

        // While the listener is alive, the port should NOT be free
        assert!(!is_port_free(port), "Port {} should not be free while bound", port);

        // After dropping, it should be free again
        drop(listener);
        assert!(is_port_free(port), "Port {} should be free after release", port);
    }
}
