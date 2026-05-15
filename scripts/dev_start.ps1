<#
.SYNOPSIS
    Startet die Sidekick-Entwicklungsumgebung (Hermes WebUI + Tauri Dev-Modus).

.DESCRIPTION
    Dieses Skript:
      1. Prüft ob Python und Rust installiert sind
      2. Führt runtime/bootstrap_venv.ps1 aus (venv + Abhängigkeiten)
      3. Startet Hermes WebUI im Hintergrund
      4. Startet Tauri im Dev-Modus (cargo tauri dev)
      5. Räumt bei Strg+C den Hermes-Prozess sauber auf

.NOTES
    PowerShell 5.1+ unter Windows.
    Der Hermes WebUI-Prozess läuft auf Port 8787 (oder $env:SIDEKICK_PORT).
#>

#Requires -Version 5.1

# ── Projekt-Root ermitteln ─────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path "$ScriptDir\.."
$HermesDir = "$ProjectRoot\vendor\hermes-webui"
$TauriDir = "$ProjectRoot\src-tauri"
$RuntimeDir = "$ProjectRoot\runtime"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗"
Write-Host "  ║       Sidekick – Dev-Start               ║"
Write-Host "  ╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  Projekt-Root : $ProjectRoot"
Write-Host ""

# ── Hilfsfunktion: Programm vorhanden? ────────────────────────────────────
function Test-Command($Command) {
    $installed = Get-Command $Command -ErrorAction SilentlyContinue
    return ($null -ne $installed)
}

# ── 1. Voraussetzungen prüfen ─────────────────────────────────────────────
Write-Host "  [1/5] Voraussetzungen prüfen ..." -NoNewline

$pythonOk = Test-Command "python" -or (Test-Command "python3")
$rustOk   = Test-Command "rustc"
$cargoOk  = Test-Command "cargo"

if (-not $pythonOk) {
    Write-Host " FEHLER" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Python wurde nicht gefunden." -ForegroundColor Red
    Write-Host "  Bitte installiere Python 3.10+ von https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "  Achte darauf, 'Add Python to PATH' bei der Installation zu aktivieren." -ForegroundColor Red
    exit 1
}
if (-not $rustOk) {
    Write-Host " FEHLER" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Rust (rustc) wurde nicht gefunden." -ForegroundColor Red
    Write-Host "  Bitte installiere Rust via: https://rustup.rs/" -ForegroundColor Red
    exit 1
}
if (-not $cargoOk) {
    Write-Host " FEHLER" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Cargo wurde nicht gefunden." -ForegroundColor Red
    Write-Host "  Rustup sollte Cargo automatisch installieren. Prüfe: rustup show" -ForegroundColor Red
    exit 1
}

Write-Host " OK" -ForegroundColor Green
Write-Host "       Python : $(python --version 2>&1)" -ForegroundColor Gray
Write-Host "       Rust   : $(rustc --version 2>&1)" -ForegroundColor Gray
Write-Host "       Cargo  : $(cargo --version 2>&1)" -ForegroundColor Gray

# ── 2. Bootstrap (venv + deps) ─────────────────────────────────────────────
Write-Host "  [2/5] Bootstrap (venv + Abhängigkeiten) ..."

$BootstrapScript = "$RuntimeDir\bootstrap_venv.ps1"
if (Test-Path $BootstrapScript) {
    Write-Host "       Führe $BootstrapScript aus ..." -ForegroundColor Gray
    & $BootstrapScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  bootstrap_venv.ps1 fehlgeschlagen (Exit-Code: $LASTEXITCODE)" -ForegroundColor Yellow
        Write-Host "  Fahre trotzdem fort – evtl. sind die Abhängigkeiten bereits installiert." -ForegroundColor Yellow
    } else {
        Write-Host "       Bootstrap erfolgreich." -ForegroundColor Green
    }
} else {
    Write-Host "       bootstrap_venv.ps1 nicht gefunden unter:" -ForegroundColor Yellow
    Write-Host "       $BootstrapScript" -ForegroundColor Yellow
    Write-Host "       Erstelle es in runtime/bootstrap_venv.ps1, um venv + deps automatisch zu setup'en." -ForegroundColor Yellow
    Write-Host "       Fahre ohne Bootstrap fort ..." -ForegroundColor Yellow
}

# ── 3. Port-Konfiguration ─────────────────────────────────────────────────
$Port = if ($env:SIDEKICK_PORT) { $env:SIDEKICK_PORT } else { 8787 }
$HostAddr = "127.0.0.1"
$StateDir = "$env:APPDATA\Sidekick\webui"

Write-Host "  [3/5] Port-Konfiguration: $HostAddr`:$Port" -ForegroundColor Gray

# ── 4. Hermes WebUI starten (Hintergrund) ──────────────────────────────────
Write-Host "  [4/5] Hermes WebUI starten (Hintergrund) ..."

# Python-Ermittlung: bevorzugt python.exe aus venv
$HermesPython = "python"
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"
if (Test-Path $VenvPython) {
    $HermesPython = $VenvPython
    Write-Host "       Verwende venv-Python: $HermesPython" -ForegroundColor Gray
} else {
    Write-Host "       Verwende System-Python: $(python --version 2>&1)" -ForegroundColor Gray
}

# Hermes WebUI als Hintergrundprozess starten (PowerShell 5.1-kompatibel)
# Umgebungsvariablen im aktuellen Prozess setzen (Kindprozess erbt sie)
$env:HERMES_WEBUI_HOST      = $HostAddr
$env:HERMES_WEBUI_PORT      = "$Port"
$env:HERMES_WEBUI_STATE_DIR = $StateDir
$env:HERMES_WEBUI_PYTHON    = $HermesPython

$HermesProcess = Start-Process -FilePath $HermesPython -ArgumentList @(
    "$HermesDir\server.py"
) -NoNewWindow -PassThru

Write-Host "       Hermes WebUI gestartet (PID: $($HermesProcess.Id))" -ForegroundColor Green

# Kurze Pause, damit der Server starten kann
Start-Sleep -Milliseconds 500

# Health-Check: auf Server warten (max. 10 Sekunden)
$HealthUrl = "http://$HostAddr`:$Port/health"
$ServerReady = $false
for ($i = 0; $i -lt 20; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $ServerReady = $true
            break
        }
    } catch {
        # Server noch nicht bereit
    }
    Start-Sleep -Milliseconds 500
}

if ($ServerReady) {
    Write-Host "       Hermes WebUI bereit: http://$HostAddr`:$Port" -ForegroundColor Green
} else {
    Write-Host "       Hermes WebUI scheint nicht zu antworten – starte trotzdem Tauri." -ForegroundColor Yellow
    Write-Host "       Prüfe die Logs falls die UI leer bleibt." -ForegroundColor Yellow
    Write-Host "       Health-Endpoint: $HealthUrl" -ForegroundColor Gray
}

# ── 5. Tauri Dev-Modus starten ────────────────────────────────────────────
Write-Host ""
Write-Host "  [5/5] Tauri Dev-Modus starten ..."
Write-Host ""
Write-Host "  ══════════════════════════════════════════"
Write-Host "  Hermes WebUI : http://$HostAddr`:$Port"
Write-Host "  Tauri Dev    : cargo tauri dev (src-tauri)"
Write-Host "  Drücke Strg+C um beide Prozesse zu beenden."
Write-Host "  ══════════════════════════════════════════"
Write-Host ""

try {
    # In das src-tauri-Verzeichnis wechseln und Tauri starten
    Push-Location $TauriDir
    cargo tauri dev
} finally {
    Pop-Location
}

# ── Aufräumen bei Beendigung ──────────────────────────────────────────────
Write-Host ""
Write-Host "  Räume auf ..."

# Hermes WebUI sauber beenden
if ($HermesProcess -and (-not $HermesProcess.HasExited)) {
    Write-Host "       Stoppe Hermes WebUI (PID: $($HermesProcess.Id)) ..."
    $HermesProcess.Kill()
    $HermesProcess.WaitForExit(5000) | Out-Null
    Write-Host "       Hermes WebUI beendet." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Sidekick Dev-Umgebung beendet." -ForegroundColor Gray
Write-Host ""
