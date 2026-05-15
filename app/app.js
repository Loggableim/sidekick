/* ============================================================
   Sidekick - Control-UI JavaScript
   Tauri IPC + Fallback für Dev-Modus
   ============================================================ */

(function () {
  'use strict';

  // ---------- Tauri API Helper ----------
  const tauri = window.__TAURI__ || null;
  const isTauri = !!tauri;

  /**
   * Ruft einen Tauri-Befehl per IPC auf.
   * Fallback: console.log im Dev-Modus.
   */
  async function invoke(cmd, args) {
    args = args || {};
    if (isTauri && tauri.invoke) {
      try {
        return await tauri.invoke(cmd, args);
      } catch (err) {
        console.error('[Sidekick] Tauri invoke error:', cmd, err);
        addLog('[FEHLER] Tauri IPC-Fehler: ' + err);
        throw err;
      }
    }
    // Dev-Modus Fallback
    console.log('[Sidekick] invoke (dev):', cmd, args);
    addLog('[DEV] invoke: ' + cmd + ' ' + JSON.stringify(args));
    return null;
  }

  // ---------- DOM References ----------
  const statusBadge = document.getElementById('status-badge');
  const logOutput = document.getElementById('log-output');
  const webviewFrame = document.getElementById('webview-frame');
  const webviewPlaceholder = document.getElementById('webview-placeholder');
  const webviewStatus = document.getElementById('webview-status');
  const errorDisplay = document.getElementById('error-display');
  const errorText = document.getElementById('error-text');

  // ---------- State ----------
  let currentStatus = 'idle';
  let pollInterval = null;
  let logBuffer = [];
  const MAX_LOG_LINES = 500;

  // ---------- Status Map (Deutsch) ----------
  const STATUS_LABELS = {
    idle: 'Nicht gestartet',
    stopped: 'Nicht gestartet',
    starting: 'Backend startet…',
    running: 'Backend läuft',
    stopping: 'Stoppe…',
    error: 'Backend nicht erreichbar',
    restarting: 'Neustart…'
  };

  const STATUS_BADGE_CLASSES = {
    idle: 'badge-idle',
    stopped: 'badge-idle',
    starting: 'badge-starting',
    running: 'badge-running',
    error: 'badge-error',
    restarting: 'badge-restarting',
    stopping: 'badge-idle'
  };

  // ---------- UI Update Functions ----------

  /**
   * Aktualisiert den Status-Badge.
   */
  function updateStatus(status) {
    currentStatus = status;
    const label = STATUS_LABELS[status] || status;
    const cls = STATUS_BADGE_CLASSES[status] || 'badge-idle';

    statusBadge.textContent = label;
    statusBadge.className = 'badge ' + cls;

    // Buttons je nach Status aktivieren/deaktivieren
    const btnStart = document.getElementById('btn-start');
    const btnStop = document.getElementById('btn-stop');
    const btnRestart = document.getElementById('btn-restart');

    switch (status) {
      case 'idle':
      case 'error':
        btnStart.disabled = false;
        btnStop.disabled = true;
        btnRestart.disabled = true;
        break;
      case 'starting':
      case 'stopping':
        btnStart.disabled = true;
        btnStop.disabled = true;
        btnRestart.disabled = true;
        break;
      case 'running':
        btnStart.disabled = true;
        btnStop.disabled = false;
        btnRestart.disabled = false;
        break;
      case 'restarting':
        btnStart.disabled = true;
        btnStop.disabled = true;
        btnRestart.disabled = true;
        break;
      default:
        btnStart.disabled = false;
        btnStop.disabled = true;
        btnRestart.disabled = true;
    }

    addLog('[STATUS] ' + label);
  }

  /**
   * Zeigt den letzten Fehler an.
   */
  function showError(msg) {
    if (!msg) {
      errorDisplay.classList.add('hidden');
      return;
    }
    errorText.textContent = msg;
    errorDisplay.classList.remove('hidden');
    errorDisplay.classList.add('slide-down');
    addLog('[FEHLER] ' + msg);
  }

  /**
   * Fügt einen Log-Eintrag hinzu.
   */
  function addLog(message) {
    var now = new Date();
    var timestamp =
      String(now.getHours()).padStart(2, '0') + ':' +
      String(now.getMinutes()).padStart(2, '0') + ':' +
      String(now.getSeconds()).padStart(2, '0');
    var entry = '[' + timestamp + '] ' + message;

    logBuffer.push(entry);
    if (logBuffer.length > MAX_LOG_LINES) {
      logBuffer.shift();
    }

    logOutput.value = logBuffer.join('\n');
    // Auto-scroll to bottom
    logOutput.scrollTop = logOutput.scrollHeight;
  }

  /**
   * Leert das Log-Panel.
   */
  function clearLogs() {
    logBuffer = [];
    logOutput.value = '';
    addLog('Logs geleert');
  }

  /**
   * Lädt Hermes WebUI in den iframe.
   */
  function loadHermesWebUI(port) {
    var url = 'http://127.0.0.1:' + (port || 8787) + '/';
    addLog('[WEBUI] Lade Hermes WebUI: ' + url);

    webviewFrame.src = url;
    webviewFrame.classList.remove('hidden');
    webviewPlaceholder.style.display = 'none';
    webviewStatus.textContent = 'Geladen';
    webviewStatus.className = 'badge badge-running';

    // Lade-Ereignis überwachen
    webviewFrame.onload = function () {
      addLog('[WEBUI] Hermes WebUI geladen');
      webviewStatus.textContent = 'Geladen';
      webviewStatus.className = 'badge badge-running';
    };

    webviewFrame.onerror = function () {
      addLog('[WEBUI] Fehler beim Laden');
      webviewStatus.textContent = 'Fehler';
      webviewStatus.className = 'badge badge-error';
    };
  }

  /**
   * Entfernt die WebUI aus dem iframe.
   */
  function unloadHermesWebUI() {
    webviewFrame.src = '';
    webviewFrame.classList.add('hidden');
    webviewPlaceholder.style.display = 'flex';
    webviewStatus.textContent = 'Nicht geladen';
    webviewStatus.className = 'badge badge-idle';
    addLog('[WEBUI] Hermes WebUI entladen');
  }

  // ---------- Hermes Actions ----------

  async function startHermes() {
    addLog('[AKTION] Hermes wird gestartet…');
    updateStatus('starting');
    showError(null);
    try {
      var result = await invoke('start_hermes', {});
      addLog('[AKTION] Hermes gestartet: ' + JSON.stringify(result));
    } catch (err) {
      updateStatus('error');
      showError('Fehler beim Starten: ' + (err.message || err));
    }
  }

  async function stopHermes() {
    addLog('[AKTION] Hermes wird gestoppt…');
    updateStatus('stopping');
    try {
      var result = await invoke('stop_hermes', {});
      addLog('[AKTION] Hermes gestoppt: ' + JSON.stringify(result));
      unloadHermesWebUI();
      updateStatus('idle');
    } catch (err) {
      updateStatus('error');
      showError('Fehler beim Stoppen: ' + (err.message || err));
    }
  }

  async function restartHermes() {
    addLog('[AKTION] Hermes wird neu gestartet…');
    updateStatus('restarting');
    unloadHermesWebUI();
    try {
      var result = await invoke('restart_hermes', {});
      addLog('[AKTION] Hermes neu gestartet: ' + JSON.stringify(result));
    } catch (err) {
      updateStatus('error');
      showError('Fehler beim Neustart: ' + (err.message || err));
    }
  }

  // ---------- Utility Actions ----------

  async function openLogs() {
    addLog('[AKTION] Zeige Logs…');
    // Wenn kein separates Log-Fenster, einfach ins Log-Panel scrollen
    var logPanel = document.getElementById('log-panel');
    if (logPanel) {
      logPanel.scrollIntoView({ behavior: 'smooth' });
    }
  }

  async function openAppData() {
    addLog('[AKTION] Öffne AppData…');
    try {
      await invoke('open_appdata', {});
    } catch (err) {
      console.warn('[Sidekick] open_appdata nicht verfügbar:', err);
      addLog('[DEV] open_appdata (simuliert)');
    }
  }

  async function openBrowser() {
    var portEl = document.getElementById('port');
    var port = portEl ? parseInt(portEl.value, 10) : 8787;
    var url = 'http://127.0.0.1:' + port + '/';
    addLog('[AKTION] Öffne im Browser: ' + url);

    if (isTauri) {
      try {
        await invoke('open_browser', { port: port });
      } catch (err) {
        console.warn('[Sidekick] open_browser nicht verfügbar:', err);
        // Fallback: window.open
        window.open(url, '_blank');
      }
    } else {
      window.open(url, '_blank');
      addLog('[DEV] Browser geöffnet (Dev-Modus)');
    }
  }

  // ---------- Settings ----------

  async function loadSettings() {
    addLog('[SETTINGS] Lade Einstellungen…');
    try {
      var settings = await invoke('get_settings', {});
      if (settings) {
        applySettings(settings);
        addLog('[SETTINGS] Einstellungen geladen');
      }
    } catch (err) {
      console.warn('[Sidekick] get_settings nicht verfügbar, verwende Standardwerte:', err);
      applySettings({
        port: 8787,
        autostart: true,
        python_path: 'python',
        hermes_path: './vendor/hermes-webui'
      });
    }
  }

  async function saveSettings() {
    var settings = collectSettings();
    addLog('[SETTINGS] Speichere Einstellungen…');
    try {
      await invoke('save_settings', { settingsData: settings });
      addLog('[SETTINGS] Einstellungen gespeichert');
    } catch (err) {
      console.warn('[Sidekick] save_settings nicht verfügbar:', err);
      addLog('[DEV] Einstellungen gespeichert (Dev-Modus): ' + JSON.stringify(settings));
    }
  }

  function collectSettings() {
    return {
      hermes_path: document.getElementById('hermes-path').value || './vendor/hermes-webui',
      python_path: document.getElementById('python-path').value || 'python',
      preferred_port: parseInt(document.getElementById('port').value, 10) || 8787,
      auto_start: document.getElementById('autostart').checked,
      auto_restart: false
    };
  }

  function applySettings(s) {
    if (s.preferred_port !== undefined) document.getElementById('port').value = s.preferred_port;
    if (s.auto_start !== undefined) document.getElementById('autostart').checked = s.auto_start;
    if (s.python_path !== undefined) document.getElementById('python-path').value = s.python_path;
    if (s.hermes_path !== undefined) document.getElementById('hermes-path').value = s.hermes_path;
  }

  // ---------- Status Polling ----------

  async function pollStatus() {
    try {
      var status = await invoke('get_status', {});
      if (status) {
        // get_status gibt einen String zurueck: "starting", "running", "stopped", "error"
        var newStatus = typeof status === 'string' ? status : (status.status || 'idle');
        if (newStatus !== currentStatus) {
          updateStatus(newStatus);
        }

        // Wenn Running, lade WebUI falls nicht geladen
        if (newStatus === 'running' && webviewFrame.classList.contains('hidden')) {
          var port = document.getElementById('port').value || 8787;
          loadHermesWebUI(port);
        }

        // Wenn nicht mehr running, entlade WebUI
        if (newStatus !== 'running' && newStatus !== 'restarting' && !webviewFrame.classList.contains('hidden')) {
          unloadHermesWebUI();
        }
      }
    } catch (err) {
      // Kein dauerhaftes Fehler-logg im Poll
      if (currentStatus === 'running') {
        updateStatus('error');
        showError('Verbindung zum Backend verloren');
      }
    }
  }

  function startPolling() {
    if (pollInterval) return;
    pollInterval = setInterval(pollStatus, 2000);
    addLog('[POLL] Status-Polling gestartet (alle 2s)');
    // Direkt ersten Poll ausführen
    pollStatus();
  }

  function stopPolling() {
    if (pollInterval) {
      clearInterval(pollInterval);
      pollInterval = null;
      addLog('[POLL] Status-Polling gestoppt');
    }
  }

  // ---------- Error Dismiss ----------
  document.getElementById('error-dismiss').addEventListener('click', function () {
    showError(null);
  });

  // ---------- Keyboard Shortcuts ----------
  document.addEventListener('keydown', function (e) {
    // Strg+L = Logs leeren
    if (e.ctrlKey && e.key === 'l') {
      e.preventDefault();
      clearLogs();
    }
    // Strg+Enter = Hermes starten
    if (e.ctrlKey && e.key === 'Enter') {
      e.preventDefault();
      if (currentStatus === 'idle' || currentStatus === 'error') {
        startHermes();
      }
    }
  });

  // ---------- Initialization ----------
  function init() {
    addLog('Sidekick Control-UI initialisiert');
    addLog('Tauri-API: ' + (isTauri ? 'verfügbar' : 'nicht verfügbar (Dev-Modus)'));

    if (!isTauri) {
      addLog('[DEV] Demo-Modus: Aktionen werden nur simuliert');
      // Demo: Status nach 3s auf "starting" setzen
      setTimeout(function () {
        updateStatus('starting');
      }, 3000);
      // Demo: nach 6s auf "running"
      setTimeout(function () {
        updateStatus('running');
        loadHermesWebUI(8787);
      }, 6000);
    }

    // Settings laden
    loadSettings();

    // Polling starten
    startPolling();
  }

  // ---------- Expose Globals (für onclick in HTML) ----------
  window.startHermes = startHermes;
  window.stopHermes = stopHermes;
  window.restartHermes = restartHermes;
  window.openLogs = openLogs;
  window.openAppData = openAppData;
  window.openBrowser = openBrowser;
  window.loadHermesWebUI = loadHermesWebUI;
  window.updateStatus = updateStatus;
  window.addLog = addLog;
  window.clearLogs = clearLogs;
  window.loadSettings = loadSettings;
  window.saveSettings = saveSettings;
  window.pollStatus = pollStatus;

  // DOM ready start
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
