<#
.SYNOPSIS
    Baut Sidekick als Release-Binary für Windows.

.DESCRIPTION
    Dieses Skript:
      1. Prüft Voraussetzungen: Rust (rustc), Node (node), Python
      2. Installiert Tauri CLI falls nötig (cargo install tauri-cli)
      3. Baut die Tauri-App via cargo tauri build
      4. Kopiert die .exe nach F:/finalbrowser/dist/
      5. Zeigt den Pfad zur Binary an

.NOTES
    PowerShell 5.1+ unter Windows.
    Erfordert WebView2 (ist auf aktuellen Windows 10/11 Systemen vorinstalliert).
#>

#Requires -Version 5.1

# ── Projekt-Root ermitteln ─────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $PSCommandPath
$ProjectRoot = Resolve-Path "$ScriptDir\.."
$TauriDir = "$ProjectRoot\src-tauri"
$DistDir = "$ProjectRoot\dist"

# ── Hilfsfunktionen ────────────────────────────────────────────────────────
function Test-Command($Command) {
    $installed = Get-Command $Command -ErrorAction SilentlyContinue
    return ($null -ne $installed)
}

function Write-Step($Title) {
    Write-Host ""
    Write-Host "  ═══ $Title ═══" -ForegroundColor Cyan
}

function Get-TauriTargetDir {
    <#
    .SYNOPSIS
    Ermittelt das Tauri-Build-Ausgabeverzeichnis.
    Standard: target/release/ (Debug), target/release/ (Release).
    #>
    return "$ProjectRoot\src-tauri\target\release"
}

# ── Header ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗"
Write-Host "  ║    Sidekick – Windows-Build              ║"
Write-Host "  ╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  Projekt-Root : $ProjectRoot"
Write-Host ""

# ── 1. Voraussetzungen prüfen ─────────────────────────────────────────────
Write-Step "1/5 – Voraussetzungen prüfen"

$prereqsOk = $true

# Rust / Cargo
if (-not (Test-Command "rustc")) {
    Write-Host "  [FEHLER] Rust (rustc) nicht gefunden." -ForegroundColor Red
    Write-Host "          Installiere Rust via: https://rustup.rs/" -ForegroundColor Red
    $prereqsOk = $false
} else {
    Write-Host "  [OK] rustc : $(rustc --version)" -ForegroundColor Green
}

if (-not (Test-Command "cargo")) {
    Write-Host "  [FEHLER] Cargo nicht gefunden." -ForegroundColor Red
    Write-Host "          Rustup sollte Cargo automatisch installieren." -ForegroundColor Red
    $prereqsOk = $false
} else {
    Write-Host "  [OK] cargo : $(cargo --version)" -ForegroundColor Green
}

# Node.js (für Tauri CLI – wird von einigen Tauri-Features benötigt)
if (-not (Test-Command "node")) {
    Write-Host "  [FEHLER] Node.js nicht gefunden." -ForegroundColor Red
    Write-Host "          Bitte installiere Node.js 18+ von https://nodejs.org/" -ForegroundColor Red
    $prereqsOk = $false
} else {
    Write-Host "  [OK] node  : $(node --version)" -ForegroundColor Green
}

# Python (wird für das Hermes WebUI-Sidecar benötigt)
if (-not (Test-Command "python")) {
    Write-Host "  [WARN] Python nicht gefunden." -ForegroundColor Yellow
    Write-Host "         Python wird zur Laufzeit für Hermes WebUI benötigt," -ForegroundColor Yellow
    Write-Host "         aber nicht für den Tauri-Build selbst." -ForegroundColor Yellow
} else {
    Write-Host "  [OK] python: $(python --version)" -ForegroundColor Green
}

if (-not $prereqsOk) {
    Write-Host ""
    Write-Host "  Bitte installiere die fehlenden Voraussetzungen und versuche es erneut." -ForegroundColor Red
    exit 1
}

# ── 2. cargo-generate / Tauri CLI prüfen ──────────────────────────────────
Write-Step "2/5 – Tauri CLI prüfen"

$tauriCliInstalled = $false
try {
    $tauriVersion = cargo tauri --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tauriCliInstalled = $true
        Write-Host "  [OK] Tauri CLI : $($tauriVersion.Trim())" -ForegroundColor Green
    }
} catch {
    # nicht installiert
}

if (-not $tauriCliInstalled) {
    Write-Host "  [INFO] Installiere Tauri CLI via cargo ..." -ForegroundColor Yellow
    Write-Host "         Das kann einige Minuten dauern." -ForegroundColor Yellow

    cargo install tauri-cli
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FEHLER] Installation von tauri-cli fehlgeschlagen." -ForegroundColor Red
        Write-Host "          Versuche: cargo install tauri-cli --locked" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [OK] Tauri CLI installiert." -ForegroundColor Green
}

# ── 3. Tauri Build ausführen ──────────────────────────────────────────────
Write-Step "3/5 – Tauri Build (Release)"

Write-Host "  Starte cargo tauri build ..." -ForegroundColor Gray
Write-Host "  (Das kann mehrere Minuten dauern – erster Build lädt Crates.)" -ForegroundColor Gray
Write-Host ""

Push-Location $TauriDir
try {
    cargo tauri build --bundles msi
    $buildExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($buildExitCode -ne 0) {
    Write-Host ""
    Write-Host "  [FEHLER] Tauri-Build fehlgeschlagen (Exit-Code: $buildExitCode)." -ForegroundColor Red
    Write-Host "          Prüfe die Build-Ausgabe oben auf Fehlermeldungen." -ForegroundColor Red
    exit 1
}

Write-Host "  [OK] Tauri-Build erfolgreich." -ForegroundColor Green

# ── 4. Binary nach dist/ kopieren ─────────────────────────────────────────
Write-Step "4/5 – Binary kopieren"

# Zielverzeichnis erstellen
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    Write-Host "  [INFO] dist/ Verzeichnis erstellt: $DistDir" -ForegroundColor Gray
}

# Tauri-Build-Ausgabe suchen
$TauriTarget = Get-TauriTargetDir
$BinaryName = "Sidekick.exe"
$MsiName    = "Sidekick*.msi"

# Tauri 2 speichert die Binary unter src-tauri/target/release/
$BinarySource = "$TauriTarget\Sidekick.exe"
$MsiSource = Get-ChildItem "$TauriTarget\bundle\msi\*Sidekick*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1

if (Test-Path $BinarySource) {
    Copy-Item -Path $BinarySource -Destination "$DistDir\$BinaryName" -Force
    Write-Host "  [OK] Binary kopiert:" -ForegroundColor Green
    Write-Host "       Quelle : $BinarySource" -ForegroundColor Gray
    Write-Host "       Ziel   : $DistDir\$BinaryName" -ForegroundColor Gray
} else {
    # Alternative: Im Bundle-Ordner suchen
    $BundleBinary = Get-ChildItem "$TauriTarget\bundle\*Sidekick*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($BundleBinary) {
        Copy-Item -Path $BundleBinary.FullName -Destination "$DistDir\$BinaryName" -Force
        Write-Host "  [OK] Binary kopiert (aus Bundle):" -ForegroundColor Green
        Write-Host "       Quelle : $($BundleBinary.FullName)" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] Konnte Sidekick.exe nicht im Build-Output finden:" -ForegroundColor Yellow
        Write-Host "         $TauriTarget" -ForegroundColor Yellow
        Write-Host "         Suche im gesamten target-Ordner ..." -ForegroundColor Yellow

        $found = Get-ChildItem -Path "$TauriTarget" -Filter "Sidekick.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            Copy-Item -Path $found.FullName -Destination "$DistDir\$BinaryName" -Force
            Write-Host "  [OK] Binary gefunden und kopiert: $($found.FullName)" -ForegroundColor Green
        } else {
            Write-Host "  [FEHLER] Sidekick.exe nicht gefunden." -ForegroundColor Red
            Write-Host "          Der Build war erfolgreich, aber die Binary fehlt." -ForegroundColor Red
            Write-Host "          Prüfe manuell: $TauriTarget" -ForegroundColor Red
            exit 1
        }
    }
}

# MSI kopieren (falls vorhanden)
if ($MsiSource) {
    $MsiDest = "$DistDir\$($MsiSource.Name)"
    Copy-Item -Path $MsiSource.FullName -Destination $MsiDest -Force
    Write-Host "  [OK] MSI-Installer kopiert:" -ForegroundColor Green
    Write-Host "       $MsiDest" -ForegroundColor Gray
} else {
    Write-Host "  [INFO] Kein MSI-Installer gefunden (nicht schlimm – die .exe reicht)." -ForegroundColor Gray
}

# ── 5. Zusammenfassung ────────────────────────────────────────────────────
Write-Step "5/5 – Build abgeschlossen"

Write-Host ""
Write-Host "  ══════════════════════════════════════════"
Write-Host "  Build erfolgreich!" -ForegroundColor Green
Write-Host ""
Write-Host "  Binary : $DistDir\$BinaryName"
Write-Host "  Größe  : $(Get-Item "$DistDir\$BinaryName" | Select-Object -ExpandProperty Length | ForEach-Object { '{0:N0} KB' -f ($_ / 1KB) })"
if ($MsiSource) {
    Write-Host "  MSI    : $DistDir\$($MsiSource.Name)"
}
Write-Host ""
Write-Host "  Nächste Schritte:"
Write-Host "   - Starte Sidekick:     .\$DistDir\$BinaryName"
Write-Host "   - Paketieren:          .\scripts\package_windows.ps1"
Write-Host "  ══════════════════════════════════════════"
Write-Host ""
