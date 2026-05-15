<#
.SYNOPSIS
    Startet die Sidekick-Entwicklungsumgebung (Hermes WebUI + Tauri Dev-Modus).
.DESCRIPTION
    1. Prueft ob Python und Rust installiert sind
    2. Fuehrt bootstrap_venv.ps1 aus (venv + Abhaengigkeiten)
    3. Startet Hermes WebUI im Hintergrund
    4. Startet Tauri im Dev-Modus (cargo tauri dev)
    5. Raeumt bei Strg+C den Hermes-Prozess sauber auf
.NOTES
    PowerShell 5.1+ unter Windows.
#>
#Requires -Version 5.1

# Projekt-Root ermitteln
$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path "$ScriptDir\.."
$HermesDir = "$ProjectRoot\vendor\hermes-webui"
$TauriDir = "$ProjectRoot\src-tauri"
$RuntimeDir = "$ProjectRoot\runtime"

Write-Host ""
Write-Host "  ===== Sidekick - Dev-Start ====="
Write-Host ""
Write-Host "  Projekt-Root : $ProjectRoot"
Write-Host ""

# Test-Command Funktion
function Test-Command($Command) {
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# === 1. Voraussetzungen prüfen ===
Write-Host "  [1/5] Voraussetzungen ..." -NoNewline

$pythonOk = (Test-Command "python") -or (Test-Command "python3")
$rustOk   = Test-Command "rustc"
$cargoOk  = Test-Command "cargo"

if (-not $pythonOk) {
    Write-Host " FEHLER" -ForegroundColor Red
    Write-Host "  Python nicht gefunden. Installiere Python 3.10+ von python.org"
    exit 1
}
if (-not $rustOk) {
    Write-Host " FEHLER" -ForegroundColor Red
    Write-Host "  Rust (rustc) nicht gefunden. Installiere via: https://rustup.rs/"
    exit 1
}
if (-not $cargoOk) {
    Write-Host " FEHLER" -ForegroundColor Red
    Write-Host "  Cargo nicht gefunden."
    exit 1
}
Write-Host " OK" -ForegroundColor Green
Write-Host "       Python: $(python --version 2>&1)"
Write-Host "       Rust:   $(rustc --version 2>&1)"
Write-Host "       Cargo:  $(cargo --version 2>&1)"

# === 2. Bootstrap (venv + deps) ===
Write-Host "  [2/5] Bootstrap ..."
$BootstrapScript = "$RuntimeDir\bootstrap_venv.ps1"
if (Test-Path $BootstrapScript) {
    Write-Host "       Fuehre bootstrap_venv.ps1 aus ..."
    & $BootstrapScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Bootstrap fehlgeschlagen (Exit: $LASTEXITCODE), fahre fort." -ForegroundColor Yellow
    } else {
        Write-Host "       Bootstrap OK." -ForegroundColor Green
    }
} else {
    Write-Host "       Kein bootstrap_venv.ps1 gefunden, fahre fort." -ForegroundColor Yellow
}

# === 3. Port-Konfiguration ===
$Port = if ($env:SIDEKICK_PORT) { $env:SIDEKICK_PORT } else { 8787 }
$HostAddr = "127.0.0.1"
$StateDir = "$env:APPDATA\Sidekick\webui"
Write-Host "  [3/5] Port: $HostAddr`:$Port"

# === 4. Hermes WebUI starten ===
Write-Host "  [4/5] Hermes WebUI starten ..."

# Python: bevorzugt aus venv
$HermesPython = "python"
$VenvPython = "$ProjectRoot\.venv\Scripts\python.exe"
if (Test-Path $VenvPython) {
    $HermesPython = $VenvPython
    Write-Host "       Venv-Python: $HermesPython"
} else {
    Write-Host "       System-Python: $(python --version 2>&1)"
}

$env:HERMES_WEBUI_HOST      = $HostAddr
$env:HERMES_WEBUI_PORT      = "$Port"
$env:HERMES_WEBUI_STATE_DIR = $StateDir
$env:HERMES_WEBUI_PYTHON    = $HermesPython

$HermesProcess = Start-Process -FilePath $HermesPython -ArgumentList @("$HermesDir\server.py") -NoNewWindow -PassThru
Write-Host "       PID: $($HermesProcess.Id)" -ForegroundColor Green
Start-Sleep -Milliseconds 500

# Health-Check (max 10s)
$HealthUrl = "http://$HostAddr`:$Port/health"
$ServerReady = $false
for ($i = 0; $i -lt 20; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $ServerReady = $true
            break
        }
    } catch {}
    Start-Sleep -Milliseconds 500
}

if ($ServerReady) {
    Write-Host "       Hermes WebUI bereit: http://$HostAddr`:$Port" -ForegroundColor Green
} else {
    Write-Host "       Hermes WebUI antwortet nicht, starte trotzdem Tauri." -ForegroundColor Yellow
}

# === 5. Tauri Dev-Modus ===
Write-Host ""
Write-Host "  [5/5] Tauri Dev-Modus ..."
Write-Host ""
Write-Host "  =================================="
Write-Host "  Hermes WebUI : http://$HostAddr`:$Port"
Write-Host "  Druecke Strg+C zum Beenden."
Write-Host "  =================================="
Write-Host ""

try {
    Push-Location $TauriDir
    # Cargo in den PATH einfuegen falls nicht vorhanden
    $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
    cargo tauri dev
} finally {
    Pop-Location
}

# Aufraeumen
Write-Host ""
Write-Host "  Raeume auf ..."
if ($HermesProcess -and (-not $HermesProcess.HasExited)) {
    $HermesProcess.Kill()
    $HermesProcess.WaitForExit(5000) | Out-Null
    Write-Host "  Hermes WebUI beendet." -ForegroundColor Green
}
Write-Host ""
Write-Host "  Sidekick Dev-Umgebung beendet."
Write-Host ""
