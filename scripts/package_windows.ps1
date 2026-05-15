<#
.SYNOPSIS
    Paketiert Sidekick für die Verteilung als MSI-Installer (Windows).

.DESCRIPTION
    Dieses Skript erstellt ein verteilbares MSI-Paket aus dem Tauri-Build.
    Es gibt zwei Wege:

    Weg A (empfohlen): Tauri-Build mit MSI-Bundle
      - Führt `cargo tauri build --bundles msi` aus
      - Das MSI liegt danach in src-tauri/target/release/bundle/msi/

    Weg B (manuell, ohne Tauri-MSI):
      - Kopiert die .exe + README in ein dist/-Verzeichnis
      - Gibt Hinweise zur manuellen MSI-Erstellung mit WiX Toolset

    EINSCHRÄNKUNGEN:
      - Tauri 2 MSI benötigt das WiX Toolset v3 (nicht v4) im PATH.
        Siehe: https://tauri.app/start/prerequisites/#wix
      - Ohne WiX wird nur Weg B (manuelle Distribution) unterstützt.
      - Das MSI ist nicht signiert – für echte Distribution ist ein
        Code-Signing-Zertifikat nötig.

.NOTES
    PowerShell 5.1+ unter Windows.
    Optional: WiX Toolset v3 für MSI-Erstellung.
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

# ── Header ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗"
Write-Host "  ║  Sidekick – Paketierung (Windows)        ║"
Write-Host "  ╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  Projekt-Root : $ProjectRoot"
Write-Host ""

# ── Prüfen ob bereits ein Build existiert ─────────────────────────────────
$BinaryPath = "$DistDir\Sidekick.exe"
$BuildExists = Test-Path $BinaryPath

if (-not $BuildExists) {
    Write-Host "  [HINWEIS] Kein Build in $DistDir gefunden." -ForegroundColor Yellow
    Write-Host "           Führe zuerst build_windows.ps1 aus oder überspringe mit -ForceBuild." -ForegroundColor Yellow
    Write-Host ""

    $answer = Read-Host "  Soll ein Build gestartet werden? (J/N) [J]"
    if ($answer -eq "" -or $answer -eq "J" -or $answer -eq "j") {
        Write-Host ""
        Write-Host "  Starte build_windows.ps1 ..." -ForegroundColor Gray
        & "$ScriptDir\build_windows.ps1"

        # Nach dem Build nochmal prüfen
        if (-not (Test-Path $BinaryPath)) {
            Write-Host "  [FEHLER] Build hat keine Binary erzeugt." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  [ABBRUCH] Kein Build vorhanden. Führe build_windows.ps1 manuell aus." -ForegroundColor Red
        exit 1
    }
}

Write-Host "  [OK] Binary gefunden: $BinaryPath" -ForegroundColor Green

# ── Weg A: WiX-Toolset prüfen (für MSI via Tauri) ────────────────────────
Write-Step "Prüfe MSI-Voraussetzungen (WiX Toolset)"

$hasWiX = $false
$wixCandle = Get-Command "candle.exe" -ErrorAction SilentlyContinue

if ($wixCandle) {
    $hasWiX = $true
    Write-Host "  [OK] WiX Toolset gefunden: candle.exe" -ForegroundColor Green
    Write-Host "       MSI-Erstellung via Tauri ist möglich." -ForegroundColor Green
} else {
    Write-Host "  [INFO] WiX Toolset nicht gefunden." -ForegroundColor Yellow
    Write-Host "         MSI-Erstellung via Tauri ist ohne WiX nicht möglich." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  WiX Toolset v3 installieren:" -ForegroundColor Gray
    Write-Host "    https://github.com/wixtoolset/wix3/releases" -ForegroundColor Gray
    Write-Host "    Oder via winget: winget install WiXToolset.WiXToolset" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Alternativ kann das WiX-Toolset über cargo installiert werden:" -ForegroundColor Gray
    Write-Host "    cargo install tauri-cli --features wix" -ForegroundColor Gray
}

# ── Paketierung ───────────────────────────────────────────────────────────
Write-Step "Paketierung"

if ($hasWiX) {
    # ── Weg A: MSI via Tauri Bundle ───────────────────────────────────────
    Write-Host "  Erstelle MSI-Paket via Tauri ..." -ForegroundColor Gray
    Write-Host "  (cargo tauri build --bundles msi)" -ForegroundColor Gray
    Write-Host ""

    Push-Location $TauriDir
    try {
        cargo tauri build --bundles msi
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [FEHLER] MSI-Build fehlgeschlagen." -ForegroundColor Red
            Write-Host "          Erstelle manuelles Paket ohne MSI ..." -ForegroundColor Yellow
            Build-ManualPackage
        } else {
            # MSI suchen und kopieren
            $MsiSource = Get-ChildItem "$TauriDir\target\release\bundle\msi\*Sidekick*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($MsiSource) {
                if (-not (Test-Path $DistDir)) {
                    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
                }
                $MsiDest = "$DistDir\$($MsiSource.Name)"
                Copy-Item -Path $MsiSource.FullName -Destination $MsiDest -Force
                Write-Host "  [OK] MSI-Installer erstellt:" -ForegroundColor Green
                Write-Host "       $MsiDest" -ForegroundColor Gray
            } else {
                Write-Host "  [WARN] MSI wurde nicht im Bundle-Ordner gefunden." -ForegroundColor Yellow
                Build-ManualPackage
            }
        }
    } finally {
        Pop-Location
    }
} else {
    # ── Weg B: Manuelles Paket (ohne MSI) ─────────────────────────────────
    Build-ManualPackage
}

# ── README kopieren ───────────────────────────────────────────────────────
Write-Step "Dokumentation kopieren"
Copy-Item -Path "$ProjectRoot\README.md" -Destination "$DistDir\README.md" -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] README.md kopiert nach $DistDir\README.md" -ForegroundColor Green

# ── Zusammenfassung ───────────────────────────────────────────────────────
Write-Step "Paketierung abgeschlossen"

Write-Host ""
Write-Host "  ══════════════════════════════════════════"
Write-Host "  Paket erstellt!" -ForegroundColor Green
Write-Host ""
Write-Host "  dist/ Inhalt:" -ForegroundColor Cyan
Get-ChildItem -Path $DistDir | ForEach-Object {
    $size = if ($_.Length -gt 1MB) {
        "{0:N1} MB" -f ($_.Length / 1MB)
    } else {
        "{0:N0} KB" -f ($_.Length / 1KB)
    }
    Write-Host "   $($_.Name)  ($size)"
}
Write-Host ""
Write-Host "  Manuelle Distribution:" -ForegroundColor Gray
Write-Host "   - ZIP den gesamten dist/ Ordner" -ForegroundColor Gray
Write-Host "   - Oder MSI-Installer verwenden (falls erstellt)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Hinweise:" -ForegroundColor Yellow
Write-Host "   - Das Paket ist NICHT signiert" -ForegroundColor Yellow
Write-Host "   - Windows Defender/SmartScreen kann eine Warnung anzeigen" -ForegroundColor Yellow
Write-Host "   - Für echte Distribution: Code-Signing-Zertifikat besorgen" -ForegroundColor Yellow
Write-Host "   - Für automatisierte Installation: MSI + Gruppenrichtlinien" -ForegroundColor Yellow
Write-Host ""

# ── Funktion: Manuelles Paket erstellen ───────────────────────────────────
function Build-ManualPackage {
    Write-Host ""
    Write-Host "  Erstelle manuelles Distributionspaket (ohne MSI) ..." -ForegroundColor Yellow

    # dist/ Verzeichnis sicherstellen
    if (-not (Test-Path $DistDir)) {
        New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    }

    # Prüfen ob Binary existiert
    if (-not (Test-Path $BinaryPath)) {
        # Fallback: Im Tauri-Build-Output suchen
        $TauriReleaseBin = "$TauriDir\target\release\Sidekick.exe"
        if (Test-Path $TauriReleaseBin) {
            Copy-Item -Path $TauriReleaseBin -Destination $BinaryPath -Force
            Write-Host "  [OK] Binary aus Tauri-Build kopiert." -ForegroundColor Green
        } else {
            Write-Host "  [FEHLER] Keine Binary gefunden. Führe build_windows.ps1 aus." -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "  [OK] Binary vorhanden: $BinaryPath" -ForegroundColor Green

    # Kurze README für Distribution erstellen
    $DistReadme = @"
# Sidekick

Eine Windows-Desktop-App die Hermes WebUI lokal startet, überwacht und in einer nativen Tauri + WebView2 Hülle anzeigt.

## Installation

1. Entpacke das ZIP-Archiv in einen beliebigen Ordner
2. Starte Sidekick.exe
3. Die App öffnet Hermes WebUI im internen WebView2-Fenster

## Voraussetzungen

- Windows 10/11 (mit WebView2 – ist standardmäßig installiert)
- Python 3.10+ (für das Hermes WebUI Backend)

## Manuelle MSI-Erstellung

Falls ein MSI-Installer gewünscht ist:
1. Installiere WiX Toolset v3: https://github.com/wixtoolset/wix3/releases
2. Führe scripts/package_windows.ps1 aus (erkennt WiX automatisch)
3. Das MSI liegt danach in dist/

## Build von Quellen

Siehe scripts/README_SCRIPTS.md für Build-Anleitung.

## Lizenz

MIT
"@

    $DistReadmePath = "$DistDir\README.txt"
    $DistReadme | Out-File -FilePath $DistReadmePath -Encoding utf8
    Write-Host "  [OK] README.txt erstellt: $DistReadmePath" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Manuelles Paket erstellt in: $DistDir" -ForegroundColor Green
    Write-Host "  ZIP den Ordner zur Verteilung." -ForegroundColor Gray
}
