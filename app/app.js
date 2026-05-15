/* ============================================================
   Sidekick - Control-UI JavaScript
   Tauri IPC + Demo-Modus Fallback
   ============================================================ */
(function () {
  'use strict';

  // ---------- Tauri API Erkennung ----------
  const tauri = window.__TAURI__ || null;
  const isTauri = !!tauri;
  const MODE = isTauri ? 'REAL' : 'DEMO';

  // ---------- DOM References ----------
  const statusBadge = document.getElementById('status-badge');
  const modeBadge = document.getElementById('mode-badge');
  const modeText = document.getElementById('mode-text');
  const modeCard = document.getElementById('mode-card');
  const logOutput = document.getElementById('log-output');
  const webviewStatus = document.getElementById('webview-status');
  const webuiUrl = document.getElementById('webui-url');
  const webuiErrorCard = document.getElementById('webui-error-card');
  const webuiErrorText = document.getElementById('webui-error-text');
  const errorDisplay = document.getElementById('error-display');
  const errorText = document.getElementById('error-text');

  // ---------- State ----------
  let currentStatus = 'idle';
  let pollInterval = null;
  let logBuffer = [];
  const MAX_LOG_LINES = 500;
  let logFilters = { DEV: true, STATUS: true, WEBUI: true, FEHLER: true };

  // ---------- Mode Display ----------
  function initModeDisplay() {
    if (MODE === 'REAL') {
      modeBadge.textContent = 'REAL IPC';
      modeBadge.className = 'badge badge-running';
      modeText.textContent = 'Modus: Echter Tauri IPC';
      modeCard.className = 'card mode-real';
      addLog('[MODE] Echter Tauri IPC Modus');
    } else {
      modeBadge.textContent = 'DEMO';
      modeBadge.className = 'badge badge-warning';
      modeText.textContent = 'Modus: Browser-Demo (kein Tauri IPC)';
      modeCard.className = 'card mode-demo';
      addLog('[MODE] [DEMO] Browser-Demo Modus — Aktionen werden nur simuliert');
      addLog('[MODE] [DEMO] Öffne die App via Tauri-Fenster für echten IPC');
    }
  }

  // ---------- Status Map ----------
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

  // ---------- Tauri IPC invoke ----------
  async function invoke(cmd, args) {
    args = args || {};
    if (MODE === 'REAL' && tauri && tauri.invoke) {
      try {
        return await tauri.invoke(cmd, args);
      } catch (err) {
        addLog('[FEHLER] Tauri IPC-Fehler bei ' + cmd + ': ' + (err.message || err));
        throw err;
      }
    }
    // Demo-Modus Fallback
    addLog('[DEV] invoke (DEMO): ' + cmd + ' ' + JSON.stringify(args));
    return null;
  }

  // ---------- UI Update Functions ----------

  function updateStatus(status) {
    currentStatus = status;
    const label = STATUS_LABELS[status] || status;
    const cls = STATUS_BADGE_CLASSES[status] || 'badge-idle';

    statusBadge.textContent = label;
    statusBadge.className = 'badge ' + cls;

    updateButtons(status);
    addLog((MODE === 'DEMO' ? '[DEV] [STATUS] ' : '[STATUS] ') + label);
  }

  function updateButtons(status) {
    const btnStart = document.getElementById('btn-start');
    const btnStop = document.getElementById('btn-stop');
    const btnRestart = document.getElementById('btn-restart');
    const btnWebuiOpen = document.getElementById('btn-webui-open');
    const btnWebuiFocus = document.getElementById('btn-webui-focus');

    btnStart.disabled = (status === 'starting' || status === 'running' || status === 'stopping');
    btnStop.disabled = (status !== 'running');
    btnRestart.disabled = (status === 'starting' || status === 'stopping' || status === 'restarting');
    btnWebuiOpen.disabled = (status !== 'running');
    btnWebuiFocus.disabled = (status !== 'running');
  }

  function showError(msg) {
    if (!msg) {
      errorDisplay.classList.add('hidden');
      return;
    }
    errorText.textContent = msg;
    errorDisplay.classList.remove('hidden');
    addLog('[FEHLER] ' + msg);
  }

  function showWebUIError(msg) {
    webuiErrorCard.classList.remove('hidden');
    webuiErrorText.textContent = msg;
    webviewStatus.textContent = 'Fehler';
    webviewStatus.className = 'badge badge-error';
    addLog('[WEBUI] Fehler: ' + msg);
  }

  function hideWebUIError() {
    webuiErrorCard.classList.add('hidden');
  }

  function addLog(message) {
    var now = new Date();
    var timestamp =
      String(now.getHours()).padStart(2, '0') + ':' +
      String(now.getMinutes()).padStart(2, '0') + ':' +
      String(now.getSeconds()).padStart(2, '0');
    var prefix = '';
    if (message.startsWith('[DEV]')) prefix = '[DEV]';
    else if (message.startsWith('[STATUS]') || message.startsWith('[AKTION') || message.startsWith('[POLL]')) prefix = '[STATUS]';
    else if (message.startsWith('[WEBUI]')) prefix = '[WEBUI]';
    else if (message.startsWith('[FEHLER]')) prefix = '[FEHLER]';
    else if (message.startsWith('[SETTINGS]')) prefix = '[STATUS]';
    else if (message.startsWith('[MODE]')) prefix = '[STATUS]';

    var entry = '[' + timestamp + '] ' + message;
    logBuffer.push({ raw: entry, prefix: prefix });

    // Alte Einträge entfernen
    while (logBuffer.length > MAX_LOG_LINES) {
      logBuffer.shift();
    }

    renderLogs();
    // Auto-scroll
    logOutput.scrollTop = logOutput.scrollHeight;
  }

  function renderLogs() {
    var filtered = logBuffer.filter(function(entry) {
      if (entry.prefix === '[DEV]' && !logFilters.DEV) return false;
      if (entry.prefix === '[STATUS]' && !logFilters.STATUS) return false;
      if (entry.prefix === '[WEBUI]' && !logFilters.WEBUI) return false;
      if (entry.prefix === '[FEHLER]' && !logFilters.FEHLER) return false;
      return true;
    });
    logOutput.value = filtered.map(function(e) { return e.raw; }).join('\n');
  }

  function toggleFilter(prefix) {
    logFilters[prefix] = !logFilters[prefix];
    var btn = document.getElementById('btn-filter-' + prefix.toLowerCase());
    if (btn) {
      btn.classList.toggle('active');
    }
    renderLogs();
  }

  window.toggleFilter = toggleFilter;

  function clearLogs() {
    logBuffer = [];
    logOutput.value = '';
    addLog('Logs geleert');
  }

  function copyLogs() {
    logOutput.select();
    document.execCommand('copy');
    addLog('[STATUS] Logs kopiert');
  }

  // ---------- Hermes Actions ----------

  async function startHermes() {
    addLog(MODE === 'DEMO' ? '[DEV] [AKTION] Hermes starten (simuliert)' : '[AKTION] Hermes wird gestartet…');
    updateStatus('starting');
    showError(null);
    hideWebUIError();
    if (MODE === 'DEMO') {
      setTimeout(function() { updateStatus('running'); }, 2000);
      setTimeout(function() {
        webviewStatus.textContent = 'Bereit';
        webviewStatus.className = 'badge badge-running';
      }, 2500);
      return;
    }
    try {
      var result = await invoke('start_hermes', {});
      addLog('[AKTION] ' + result);
      webviewStatus.textContent = 'Bereit';
      webviewStatus.className = 'badge badge-running';
      webuiUrl.textContent = 'http://127.0.0.1:' + (document.getElementById('port').value || 8787);
    } catch (err) {
      updateStatus('error');
      var msg = err.message || err;
      showError('Fehler beim Starten: ' + msg);
      webviewStatus.textContent = 'Fehler';
      webviewStatus.className = 'badge badge-error';
    }
  }

  async function stopHermes() {
    addLog(MODE === 'DEMO' ? '[DEV] [AKTION] Hermes stoppen (simuliert)' : '[AKTION] Hermes wird gestoppt…');
    updateStatus('stopping');
    if (MODE === 'DEMO') {
      setTimeout(function() { updateStatus('idle'); }, 1000);
      return;
    }
    try {
      await invoke('stop_hermes', {});
      updateStatus('idle');
      webviewStatus.textContent = 'Nicht geladen';
      webviewStatus.className = 'badge badge-idle';
      hideWebUIError();
    } catch (err) {
      updateStatus('error');
      showError('Fehler beim Stoppen: ' + (err.message || err));
    }
  }

  async function restartHermes() {
    addLog(MODE === 'DEMO' ? '[DEV] [AKTION] Hermes neu starten (simuliert)' : '[AKTION] Hermes wird neu gestartet…');
    updateStatus('restarting');
    showError(null);
    hideWebUIError();
    if (MODE === 'DEMO') {
      var self = this;
      setTimeout(function() { updateStatus('running'); }, 3000);
      return;
    }
    try {
      var result = await invoke('restart_hermes', {});
      addLog('[AKTION] ' + result);
      webviewStatus.textContent = 'Bereit';
      webviewStatus.className = 'badge badge-running';
    } catch (err) {
      updateStatus('error');
      showError('Fehler beim Neustart: ' + (err.message || err));
    }
  }

  async function openHermesWebUI() {
    var port = document.getElementById('port').value || 8787;
    var webuiMode = document.getElementById('webui-mode').value;
    addLog('[WEBUI] Öffne Hermes WebUI (Modus: ' + webuiMode + ')');

    if (MODE === 'DEMO') {
      window.open('http://127.0.0.1:' + port + '/', '_blank');
      addLog('[DEV] [WEBUI] Browser geöffnet (Demo-Modus)');
      return;
    }

    if (webuiMode === 'browser') {
      try {
        await invoke('open_external_browser', { port: parseInt(port, 10) });
      } catch (err) {
        showWebUIError('Browser öffnen fehlgeschlagen: ' + (err.message || err));
      }
    } else if (webuiMode === 'disabled') {
      showWebUIError('WebUI öffnen ist in den Einstellungen deaktiviert');
    } else {
      // Default: separates Tauri-Fenster
      try {
        await invoke('open_hermes_window', { port: parseInt(port, 10) });
        addLog('[WEBUI] Hermes WebUI in eigenem Fenster geöffnet');
        webviewStatus.textContent = 'Eigenes Fenster';
        webviewStatus.className = 'badge badge-running';
        hideWebUIError();
      } catch (err) {
        showWebUIError('WebUI-Fenster konnte nicht geöffnet werden: ' + (err.message || err));
      }
    }
  }

  async function focusHermesWebUI() {
    if (MODE === 'DEMO') {
      addLog('[DEV] [WEBUI] Fokussieren (Demo)');
      return;
    }
    var port = document.getElementById('port').value || 8787;
    try {
      await invoke('open_hermes_window', { port: parseInt(port, 10) });
      addLog('[WEBUI] WebUI-Fenster fokussiert');
    } catch (err) {
      if ((err.message || err).indexOf('nicht gestartet') !== -1) {
        showWebUIError('Hermes WebUI ist nicht gestartet. Starte zuerst das Backend.');
      } else {
        showWebUIError('Fenster fokussieren fehlgeschlagen: ' + (err.message || err));
      }
    }
  }

  // ---------- Utility Actions ----------

  async function openLogs() {
    addLog('[AKTION] Zeige Logs…');
    var logPanel = document.getElementById('log-panel');
    if (logPanel) logPanel.scrollIntoView({ behavior: 'smooth' });
  }

  async function openAppData() {
    if (MODE === 'DEMO') {
      addLog('[DEV] AppData öffnen (Demo — ohne Tauri IPC nicht möglich)');
      return;
    }
    try {
      await invoke('open_appdata', {});
      addLog('[AKTION] AppData-Ordner geöffnet');
    } catch (err) {
      addLog('[FEHLER] AppData öffnen fehlgeschlagen: ' + (err.message || err));
    }
  }

  async function openBrowser() {
    var portEl = document.getElementById('port');
    var port = portEl ? parseInt(portEl.value, 10) : 8787;
    var url = 'http://127.0.0.1:' + port + '/';
    addLog('[AKTION] Öffne im Browser: ' + url);

    if (MODE === 'REAL') {
      try {
        await invoke('open_external_browser', { port: port });
      } catch (err) {
        window.open(url, '_blank');
      }
    } else {
      window.open(url, '_blank');
      addLog('[DEV] Browser geöffnet (Demo-Modus)');
    }
  }

  // ---------- Settings ----------

  async function loadSettings() {
    addLog('[SETTINGS] Lade Einstellungen…');
    if (MODE === 'DEMO') {
      addLog('[DEV] [SETTINGS] Demo: Standardwerte geladen');
      return;
    }
    try {
      var settings = await invoke('get_settings', {});
      if (settings) applySettings(settings);
      addLog('[SETTINGS] Einstellungen geladen');
    } catch (err) {
      addLog('[DEV] [SETTINGS] Konnte nicht laden, verwende Standardwerte');
    }
  }

  async function saveSettings() {
    var settings = collectSettings();
    addLog('[SETTINGS] Speichere Einstellungen…');
    if (MODE === 'DEMO') {
      addLog('[DEV] [SETTINGS] Gespeichert (Demo): ' + JSON.stringify(settings));
      return;
    }
    try {
      await invoke('save_settings', { settingsData: settings });
      addLog('[SETTINGS] Einstellungen gespeichert');
    } catch (err) {
      addLog('[FEHLER] Speichern fehlgeschlagen: ' + (err.message || err));
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
    webuiUrl.textContent = 'http://127.0.0.1:' + (s.preferred_port || 8787);
  }

  // ---------- Status Polling ----------

  async function pollStatus() {
    if (MODE === 'DEMO') {
      // Demo: nichts tun, Demo-Timer läuft
      return;
    }
    try {
      var status = await invoke('get_status', {});
      if (status) {
        var newStatus = typeof status === 'string' ? status : (status.status || 'idle');
        if (newStatus !== currentStatus) {
          updateStatus(newStatus);
        }
        if (newStatus === 'running') {
          webviewStatus.textContent = 'Bereit';
          webviewStatus.className = 'badge badge-running';
          hideWebUIError();
        }
      }
    } catch (err) {
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
    if (e.ctrlKey && e.key === 'l') {
      e.preventDefault();
      clearLogs();
    }
    if (e.ctrlKey && e.key === 'Enter') {
      e.preventDefault();
      if (currentStatus === 'idle' || currentStatus === 'error') {
        startHermes();
      }
    }
  });

  // ---------- Initialization ----------
  function init() {
    initModeDisplay();
    addLog('Sidekick Control-UI initialisiert');

    // Settings laden
    loadSettings();

    // Polling starten (nur im REAL-Modus)
    startPolling();

    if (MODE === 'DEMO') {
      addLog('[DEV] ===== DEMO-MODUS =====');
      addLog('[DEV] Öffne die App via Tauri-Fenster für echten IPC.');
      addLog('[DEV] Release-Binary: F:\\finalbrowser\\src-tauri\\target\\release\\sidekick.exe');
      addLog('[DEV] ======================');
    }
  }

  // ---------- Expose Globals ----------
  window.startHermes = startHermes;
  window.stopHermes = stopHermes;
  window.restartHermes = restartHermes;
  window.openHermesWebUI = openHermesWebUI;
  window.focusHermesWebUI = focusHermesWebUI;
  window.openLogs = openLogs;
  window.openAppData = openAppData;
  window.openBrowser = openBrowser;
  window.loadSettings = loadSettings;
  window.saveSettings = saveSettings;
  window.clearLogs = clearLogs;
  window.copyLogs = copyLogs;
  window.pollStatus = pollStatus;
  window.updateStatus = updateStatus;
  window.addLog = addLog;

  // Start
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
