#!/usr/bin/env bash
set -euo pipefail

# WSL-friendly autostart launcher for Sidekick.
#
# Safe defaults:
# - derives the repo from this script location, override with SIDEKICK_WEBUI_REPO
# - uses a lock + pid file to avoid duplicate starts
# - treats a healthy /health endpoint as "already running"
# - writes logs under ~/.hermes/webui/logs unless SIDEKICK_WEBUI_LOG_DIR is set

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SIDEKICK_WEBUI_REPO="${SIDEKICK_WEBUI_REPO:-${HERMES_WEBUI_REPO:-${DEFAULT_REPO}}}"
SIDEKICK_WEBUI_LOG_DIR="${SIDEKICK_WEBUI_LOG_DIR:-${HERMES_WEBUI_LOG_DIR:-${HOME}/.hermes/webui/logs}}"
SIDEKICK_WEBUI_HOST="${SIDEKICK_WEBUI_HOST:-${HERMES_WEBUI_HOST:-127.0.0.1}}"
SIDEKICK_WEBUI_PORT="${SIDEKICK_WEBUI_PORT:-${HERMES_WEBUI_PORT:-8787}}"
SIDEKICK_WEBUI_HEALTH_HOST="${SIDEKICK_WEBUI_HEALTH_HOST:-${HERMES_WEBUI_HEALTH_HOST:-127.0.0.1}}"
SIDEKICK_WEBUI_HEALTH_URL="${SIDEKICK_WEBUI_HEALTH_URL:-${HERMES_WEBUI_HEALTH_URL:-http://${SIDEKICK_WEBUI_HEALTH_HOST}:${SIDEKICK_WEBUI_PORT}/health}}"
SIDEKICK_WEBUI_PID_FILE="${SIDEKICK_WEBUI_PID_FILE:-${HERMES_WEBUI_PID_FILE:-${SIDEKICK_WEBUI_LOG_DIR}/sidekick-webui.pid}}"
SIDEKICK_WEBUI_LOCK_FILE="${SIDEKICK_WEBUI_LOCK_FILE:-${HERMES_WEBUI_LOCK_FILE:-/tmp/sidekick-webui-autostart.lock}}"
AUTOSTART_LOG="${SIDEKICK_WEBUI_LOG_DIR}/webui_autostart.log"
WEBUI_LOG="${SIDEKICK_WEBUI_LOG_DIR}/sidekick_webui.log"

# Make the WSL launcher knobs visible to start.sh/bootstrap.py.
export SIDEKICK_WEBUI_HOST SIDEKICK_WEBUI_PORT
export HERMES_WEBUI_HOST="${SIDEKICK_WEBUI_HOST}" HERMES_WEBUI_PORT="${SIDEKICK_WEBUI_PORT}"

mkdir -p "${SIDEKICK_WEBUI_LOG_DIR}"
chmod 700 "${SIDEKICK_WEBUI_LOG_DIR}" 2>/dev/null || true

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*" | tee -a "${AUTOSTART_LOG}"
}

webui_healthy() {
  command -v curl >/dev/null 2>&1 \
    && curl -fsS --max-time 3 "${SIDEKICK_WEBUI_HEALTH_URL}" >/dev/null 2>&1
}

pid_is_alive() {
  [[ -s "${SIDEKICK_WEBUI_PID_FILE}" ]] || return 1
  local pid
  pid="$(cat "${SIDEKICK_WEBUI_PID_FILE}" 2>/dev/null || true)"
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  kill -0 "${pid}" >/dev/null 2>&1
}

validate_repo() {
  if [[ ! -d "${SIDEKICK_WEBUI_REPO}" ]]; then
    log "Sidekick repo not found: ${SIDEKICK_WEBUI_REPO}"
    exit 1
  fi
  if [[ ! -f "${SIDEKICK_WEBUI_REPO}/start.sh" ]]; then
    log "start.sh not found under SIDEKICK_WEBUI_REPO=${SIDEKICK_WEBUI_REPO}"
    exit 1
  fi
}

maybe_require_agent_process() {
  # Sidekick usually launches the agent in-process, so this check is opt-in.
  # Set SIDEKICK_WEBUI_REQUIRE_AGENT_PROCESS=1 only if your setup depends on a
  # separately running Sidekick gateway/agent before WebUI starts.
  if [[ "${SIDEKICK_WEBUI_REQUIRE_AGENT_PROCESS:-${HERMES_WEBUI_REQUIRE_AGENT_PROCESS:-0}}" != "1" ]]; then
    return 0
  fi
  if ! pgrep -f "hermes" >/dev/null 2>&1; then
    log "SIDEKICK_WEBUI_REQUIRE_AGENT_PROCESS=1 but no Sidekick process is running; skipping start"
    exit 1
  fi
}

acquire_lock() {
  exec 9>"${SIDEKICK_WEBUI_LOCK_FILE}"
  if command -v flock >/dev/null 2>&1; then
    if ! flock -n 9; then
      log "Autostart already running; lock held at ${SIDEKICK_WEBUI_LOCK_FILE}"
      exit 0
    fi
  else
    log "flock not found; continuing without lock-based duplicate protection"
  fi
}

start_webui() {
  validate_repo
  maybe_require_agent_process

  if webui_healthy; then
    log "Sidekick already running at ${SIDEKICK_WEBUI_HEALTH_URL}"
    exit 0
  fi

  if pid_is_alive; then
    log "Sidekick already running with pid $(cat "${SIDEKICK_WEBUI_PID_FILE}")"
    exit 0
  fi

  rm -f "${SIDEKICK_WEBUI_PID_FILE}"
  log "Starting Sidekick from ${SIDEKICK_WEBUI_REPO} on ${SIDEKICK_WEBUI_HOST}:${SIDEKICK_WEBUI_PORT}"

  (
    cd "${SIDEKICK_WEBUI_REPO}"
    nohup bash "${SIDEKICK_WEBUI_REPO}/start.sh" --foreground >>"${WEBUI_LOG}" 2>&1 &
    printf '%s\n' "$!" >"${SIDEKICK_WEBUI_PID_FILE}"
  )

  sleep "${SIDEKICK_WEBUI_STARTUP_GRACE_SECONDS:-${HERMES_WEBUI_STARTUP_GRACE_SECONDS:-2}}"
  if webui_healthy; then
    log "Sidekick started and passed health check"
    exit 0
  fi

  if pid_is_alive; then
    log "Sidekick process started with pid $(cat "${SIDEKICK_WEBUI_PID_FILE}"); health check not ready yet"
    exit 0
  fi

  log "Sidekick failed to stay running; see ${WEBUI_LOG}"
  exit 1
}

acquire_lock
start_webui
