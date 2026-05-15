<#
.SYNOPSIS
    Sidekick Runtime Bootstrap — erzeugt venv und installiert Hermes-WebUI-Abhaengigkeiten.
.DESCRIPTION
    Prueft Python-Verfuegbarkeit, erzeugt venv unter %APPDATA%\Sidekick\runtime\venv,
    installiert pyyaml via pip.
    Idempotent: mehrfaches Ausfuehren ist sicher.
.NOTES
    PowerShell 5.1+ unter Windows.
#>
#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# Farben fuer Ausgaben
$ColorInfo = "Cyan"
$ColorOk = "Green"
$ColorWarn = "Yellow"
$ColorError = "Red"
$ColorGray = "Gray"

function Write-Status($Text, $Color = $ColorGray) {
    Write-Host ("  " + $Text) -ForegroundColor $Color
}

function Write-StatusOk($Text) { Write-Status $Text $ColorOk }
function Write-StatusWarn($Text) { Write-Status $Text $ColorWarn }
function Write-StatusError($Text) { Write-Status $Text $ColorError }

Write-Host ""
Write-Host "  ===== Sidekick Runtime Bootstrap ====="
Write-Host ""

# === 1. PowerShell Version pruefen ===
Write-Status "[1/7] PowerShell Version ..." -Color $ColorInfo
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-StatusError "PowerShell 5.1 oder neuer erforderlich (gefunden: $($PSVersionTable.PSVersion))"
    exit 1
}
Write-StatusOk "OK  PowerShell $($PSVersionTable.PSVersion)"

# === 2. Windows Version pruefen ===
Write-Status "[2/7] Windows Version ..." -Color $ColorInfo
try {
    $winVer = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentMajorVersionNumber
    if ($winVer -lt 10) {
        Write-StatusWarn "Windows 10 oder neuer empfohlen"
    } else {
        Write-StatusOk "OK  Windows 10+"
    }
} catch {
    Write-StatusWarn "Konnte Windows-Version nicht ermitteln"
}

# === 3. WebView2 Check ===
Write-Status "[3/7] WebView2 Runtime ..." -Color $ColorInfo
$wv2key = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
if (Test-Path $wv2key) {
    Write-StatusOk "OK  WebView2 ist installiert"
} else {
    Write-StatusWarn "WebView2 nicht gefunden (wird von Tauri benoetigt)"
    Write-StatusWarn "Installiere von: https://developer.microsoft.com/en-us/microsoft-edge/webview2/"
}

# === 4. Python Suche ===
Write-Status "[4/7] Python Interpreter ..." -Color $ColorInfo
$pythonExe = $null
$pythonVersion = $null

# Versuche py launcher
try {
    $pyOut = & py --list 2>&1 | Out-String
    if ($pyOut -match "3\.(\d+)") {
        $pythonExe = "py"
        $pythonVersion = "3.$($Matches.1)"
        Write-StatusOk "OK  Python $pythonVersion (via py launcher)"
    }
} catch {}

# Fallback: python
if (-not $pythonExe) {
    try {
        $ver = & python --version 2>&1
        if ($ver -match "Python 3\.(\d+)") {
            $pythonExe = "python"
            $pythonVersion = "3.$($Matches.1)"
            Write-StatusOk "OK  Python $pythonVersion"
        }
    } catch {}
}

if (-not $pythonExe) {
    Write-StatusError "Python 3.10+ nicht gefunden."
    Write-StatusError "Installiere von: https://www.python.org/downloads/"
    Write-StatusError "Achte auf 'Add Python to PATH' bei der Installation."
    exit 1
}

# === 5. Venv erstellen ===
Write-Status "[5/7] Python venv ..." -Color $ColorInfo
$venvDir = "$env:APPDATA\Sidekick\runtime\venv"
$venvPython = "$venvDir\Scripts\python.exe"

if (Test-Path $venvPython) {
    # Venv existiert bereits — pruefen ob es noch funktioniert
    try {
        $ver = & $venvPython --version 2>&1
        if ($ver -match "Python") {
            Write-StatusOk "OK  venv existiert: $venvDir"
        } else {
            throw "venv defekt"
        }
    } catch {
        Write-StatusWarn "venv defekt, erstelle neu ..."
        Remove-Item -Recurse -Force $venvDir -ErrorAction SilentlyContinue
        & $pythonExe -m venv $venvDir
        Write-StatusOk "OK  venv neu erstellt"
    }
} else {
    Write-Status "Erstelle venv in $venvDir ..."
    try {
        & $pythonExe -m venv $venvDir
        Write-StatusOk "OK  venv erstellt"
    } catch {
        Write-StatusError "Venv-Erstellung fehlgeschlagen: $_"
        exit 1
    }
}

# === 6. Requirements installieren ===
Write-Status "[6/7] requirements ..." -Color $ColorInfo
try {
    # pip updaten
    & $venvPython -m pip install --upgrade pip --quiet 2>&1 | Out-Null

    # pyyaml installieren
    & $venvPython -m pip install pyyaml>=6.0 --quiet 2>&1
    Write-StatusOk "OK  pyyaml installiert"

    # Verifikation
    $yamlVer = & $venvPython -c "import yaml; print(yaml.__version__)" 2>&1
    Write-StatusOk "OK  pyyaml Version $yamlVer"
} catch {
    Write-StatusError "pip install fehlgeschlagen: $_"
    Write-StatusWarn "Venv ist trotzdem verfuegbar unter: $venvDir"
}

# === 7. Zusammenfassung ===
Write-Host ""
Write-Host "  ===== Bootstrap abgeschlossen =====" -ForegroundColor Green
Write-Host ""
Write-StatusOk "Python : $pythonVersion ($venvPython)"
Write-StatusOk "Venv   : $venvDir"
Write-StatusOk "pyyaml : installiert"
Write-Host ""
Write-StatusOk "Sidekick kann jetzt gestartet werden."
Write-Host ""
