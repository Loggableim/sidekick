<#
.SYNOPSIS
    Beendet alle Sidekick- und Hermes-WebUI-bezogenen Prozesse.
.DESCRIPTION
    Sucht und beendet:
    - sidekick.exe (Tauri App)
    - server.py (Hermes WebUI Python Server)
    - python.exe *wenn* es server.py ausfuehrt (via tasklist Filter)
    - cargo.exe / cargo-tauri.exe (wenn im Dev-Modus)

    NICHT blind alle python.exe Prozesse beenden.
.NOTES
    PowerShell 5.1+ unter Windows.
#>
#Requires -Version 5.1

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "  ===== Sidekick Prozesse beenden ====="
Write-Host ""

$killed = @()

# 1. sidekick.exe
$sk = Get-Process -Name "sidekick" -ErrorAction SilentlyContinue
if ($sk) {
    foreach ($p in $sk) {
        Write-Host "  Beende sidekick.exe (PID: $($p.Id))" -ForegroundColor Yellow
        Stop-Process -Id $p.Id -Force
        $killed += "sidekick.exe"
    }
}

# 2. Python-Prozesse die server.py ausfuehren
# Suche via WMI nach python.exe mit CommandLine die "server.py" enthaelt
try {
    $pyProcesses = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $pyProcesses) {
        if ($p.CommandLine -match "server\.py") {
            Write-Host "  Beende python.exe (PID: $($p.ProcessId)) - Hermes WebUI" -ForegroundColor Yellow
            Stop-Process -Id $p.ProcessId -Force
            $killed += "python.exe (server.py)"
        }
    }
} catch {
    # Fallback: taskkill mit Filtern (ungenauer)
    $result = taskkill /F /FI "IMAGENAME eq python.exe" /FI "WINDOWTITLE eq *server*" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Beende python.exe (Hermes WebUI)" -ForegroundColor Yellow
        $killed += "python.exe"
    }
}

# 3. cargo / cargo-tauri (Dev-Modus)
$cargo = Get-Process -Name "cargo*" -ErrorAction SilentlyContinue
if ($cargo) {
    foreach ($p in $cargo) {
        Write-Host "  Beende $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Yellow
        Stop-Process -Id $p.Id -Force
        $killed += $p.ProcessName
    }
}

if ($killed.Count -eq 0) {
    Write-Host "  Keine Sidekick-Prozesse gefunden." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Beendet: $($killed -join ', ')" -ForegroundColor Green
}
Write-Host ""
