<#
.SYNOPSIS
    Sidekick – Windows-Bootstrap für Python-Venv und Runtime-Prüfung

.DESCRIPTION
    Prüft die Systemvoraussetzungen (Windows 10+, PowerShell 5.1+, Python 3.10+,
    WebView2), erstellt ein isoliertes Python-Venv in %APPDATA%\Sidekick\runtime\venv
    und installiert die benötigten Abhängigkeiten (pyyaml) aus vendor/hermes-webui/.

    Exit-Code: 0 bei Erfolg, 1 bei Fehler.

.NOTES
    Version: 1.0
    Autor:   Sidekick-Team
    Sprache: Deutsch (Kommentare und UI-Texte)
#>

[CmdletBinding()]
param(
    # Pfad zum Vendor-Verzeichnis mit Hermes WebUI
    [string]$VendorDir = "",

    # Zielverzeichnis für das venv (Standard: %APPDATA%\Sidekick\runtime\venv)
    [string]$VenvDir = "",

    # Mindest-Python-Version (major.minor)
    [Version]$MinPythonVersion = [Version]"3.10",

    # Mindest-Windows-Version (major.minor.build)
    [Version]$MinWindowsVersion = [Version]"10.0.10240",

    # Mindest-PowerShell-Version
    [Version]$MinPSVersion = [Version]"5.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------
$ScriptName = "Sidekick-Bootstrap"
$WebView2RegPath = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
$PythonOrgUrl = "https://www.python.org/downloads/"
$WebView2Url = "https://developer.microsoft.com/en-us/microsoft-edge/webview2/"

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

function Write-StatusOk {
    <#
    .SYNOPSIS
    Gibt eine grüne Erfolgsmeldung aus.
    #>
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-StatusInfo {
    <#
    .SYNOPSIS
    Gibt eine gelbe Informationsmeldung aus.
    #>
    param([string]$Message)
    Write-Host "[..] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-StatusError {
    <#
    .SYNOPSIS
    Gibt eine rote Fehlermeldung aus.
    #>
    param([string]$Message)
    Write-Host "[FEHLER] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-StatusFatal {
    <#
    .SYNOPSIS
    Gibt eine rote Fehlermeldung aus und beendet das Skript mit Exit-Code 1.
    #>
    param([string]$Message)
    Write-StatusError $Message
    exit 1
}

function Test-CommandExists {
    <#
    .SYNOPSIS
    Prüft, ob ein Befehl auf dem PATH existiert.
    #>
    param([string]$CommandName)
    $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-PythonExe {
    <#
    .SYNOPSIS
    Findet einen geeigneten Python-Interpreter (3.10+).
    Zuerst wird `py --list` (Python Launcher) versucht, dann `python --version`.

    .OUTPUTS
    Gibt den Pfad zur python.exe zurück, oder $null, wenn keine gefunden wurde.
    #>
    $pythonExe = $null
    $versionFound = $null

    # --- Versuch 1: Python Launcher (py --list) ---
    if (Test-CommandExists "py") {
        Write-StatusInfo "Python Launcher (py) gefunden – suche nach Python $($MinPythonVersion.Major).x ..."
        try {
            # py --list gibt Zeilen wie aus: " -3.12-64           Python 3.12 (64-bit)"
            $pyList = & py --list 2>&1
            $pyFound = $false
            foreach ($line in $pyList) {
                if ($line -match '^\s*-\s*(\d+\.\d+)') {
                    $verStr = $Matches[1]
                    $ver = [Version]"$verStr.0"
                    if ($ver -ge $MinPythonVersion) {
                        Write-StatusOk "Python $verStr gefunden über py Launcher."
                        # python mit entsprechender Version aufrufen
                        # py -3.12 -c "..."  oder py -3.10 -c "..."
                        $pyMajorMinor = $verStr
                        $testCode = & py -$pyMajorMinor -c "import sys; print(sys.executable)" 2>&1
                        if ($LASTEXITCODE -eq 0 -and $testCode) {
                            $pythonExe = $testCode.Trim()
                            $versionFound = $ver
                            $pyFound = $true
                            break
                        }
                    }
                }
            }
            if (-not $pyFound) {
                Write-StatusInfo "py-Launcher vorhanden, aber keine Python $($MinPythonVersion.Major).x registriert."
            }
        }
        catch {
            Write-StatusInfo "py --list fehlgeschlagen, versuche python direkt."
        }
    }

    # --- Versuch 2: python direkt ---
    if (-not $pythonExe -and (Test-CommandExists "python")) {
        Write-StatusInfo "Prüfe Python direkt ..."
        try {
            $verOutput = & python --version 2>&1
            if ($verOutput -match 'Python (\d+\.\d+)\.\d+') {
                $verStr = $Matches[1]
                $ver = [Version]"$verStr.0"
                if ($ver -ge $MinPythonVersion) {
                    $pythonExe = (Get-Command python).Source
                    $versionFound = $ver
                    Write-StatusOk "Python $verStr gefunden: $pythonExe"
                }
                else {
                    Write-StatusInfo "Python $verStr ist zu alt (benötigt $($MinPythonVersion.Major).$($MinPythonVersion.Minor)+)."
                }
            }
        }
        catch {
            Write-StatusInfo "python --version fehlgeschlagen."
        }
    }

    if (-not $pythonExe) {
        return $null
    }

    # Stelle sicher, dass es eine exe ist
    if ($pythonExe -and -not $pythonExe.EndsWith(".exe")) {
        $pythonExe = $pythonExe.Trim()
    }

    return $pythonExe
}

function Get-ProductVersionFromRegistry {
    <#
    .SYNOPSIS
    Liest einen REG_SZ/String-Wert aus der Registry.
    #>
    param(
        [string]$RegPath,
        [string]$ValueName = ""
    )
    try {
        if (Test-Path $RegPath) {
            $item = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction SilentlyContinue
            if ($item -and $item.$ValueName) {
                return $item.$ValueName
            }
            return $null
        }
    }
    catch {
        return $null
    }
    return $null
}

# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  $ScriptName" -ForegroundColor Cyan
Write-Host "  Runtime-Prüfung und Venv-Einrichtung" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- Standard-Pfade setzen (falls nicht über Parameter angegeben) ----
if (-not $VendorDir) {
    # Standard: Projektverzeichnis ermitteln (Skript-Pfad: runtime/bootstrap_venv.ps1)
    $ScriptPath = $MyInvocation.MyCommand.Path
    $ScriptDir = Split-Path -Parent $ScriptPath -Resolve
    $ProjectRoot = Split-Path -Parent $ScriptDir  # Eine Ebene hoch: runtime/ → Projektroot
    $VendorDir = Join-Path -Path $ProjectRoot -ChildPath "vendor\hermes-webui"
}

if (-not $VenvDir) {
    $BaseDir = $env:APPDATA
    if (-not $BaseDir) {
        Write-StatusFatal "Umgebungsvariable APPDATA ist nicht gesetzt."
    }
    $VenvDir = Join-Path -Path $BaseDir -ChildPath "Sidekick\runtime\venv"
}

$RequirementsFile = Join-Path -Path $VendorDir -ChildPath "requirements.txt"

Write-StatusInfo "Vendor-Verzeichnis : $VendorDir"
Write-StatusInfo "Venv-Zielverzeichnis: $VenvDir"
Write-StatusInfo "Requirements-Datei  : $RequirementsFile"
Write-Host ""

# ===================================================================
# 1. PowerShell-Version prüfen
# ===================================================================
Write-StatusInfo "Prüfe PowerShell-Version ..."
$currentPSVersion = $PSVersionTable.PSVersion
if ($currentPSVersion -lt $MinPSVersion) {
    Write-StatusFatal "PowerShell $currentPSVersion ist zu alt. Benötigt wird PowerShell $($MinPSVersion.Major).$($MinPSVersion.Minor)+."
}
Write-StatusOk "PowerShell $currentPSVersion erkannt."

# ===================================================================
# 2. Windows-Version prüfen
# ===================================================================
Write-StatusInfo "Prüfe Windows-Version ..."
$osInfo = Get-ComputerInfo -Property OsName, OsVersion, WindowsVersion, WindowsBuildLabEx
$osVersionStr = $osInfo.OsVersion

if ($osVersionStr) {
    try {
        $osVersion = [Version]$osVersionStr
        if ($osVersion -lt $MinWindowsVersion) {
            Write-StatusFatal "Windows $osVersionStr wird nicht unterstützt. Mindestens Windows 10 (Build 10240) erforderlich."
        }
        Write-StatusOk "Windows $($osInfo.OsName) (Version $osVersionStr) – unterstützt."
    }
    catch {
        Write-StatusInfo "Windows-Version konnte nicht geparst werden ($osVersionStr) – überspringe Prüfung."
    }
}
else {
    Write-StatusInfo "Windows-Version nicht ermittelbar – überspringe Prüfung."
}

# ===================================================================
# 3. WebView2-Prüfung (Registry)
# ===================================================================
Write-StatusInfo "Prüfe WebView2 Runtime ..."
$webView2Version = Get-ProductVersionFromRegistry -RegPath $WebView2RegPath -ValueName "pv"
if ($webView2Version) {
    Write-StatusOk "WebView2 Runtime vorhanden (Version: $webView2Version)."
}
else {
    Write-StatusError "WebView2 Runtime nicht gefunden."
    Write-Host "       Bitte lade die WebView2 Evergreen Runtime von:" -ForegroundColor Yellow
    Write-Host "       $WebView2Url" -ForegroundColor Yellow
    Write-Host "       Hinweis: Windows 11 hat WebView2 vorinstalliert. Auf Windows 10 (1803+) wird es über Edge-Updates bereitgestellt." -ForegroundColor Yellow
    Write-Host ""
    # Kein Abbruch – WebView2 kann später nachinstalliert werden, Sidekick startet dann beim nächsten Mal
}

# ===================================================================
# 4. Python finden und prüfen
# ===================================================================
Write-StatusInfo "Suche Python $($MinPythonVersion.Major).$($MinPythonVersion.Minor)+ ..."
$pythonExe = Get-PythonExe

if (-not $pythonExe) {
    Write-Host ""
    Write-StatusError "Python $($MinPythonVersion.Major).$($MinPythonVersion.Minor)+ wurde nicht gefunden!"
    Write-Host ""
    Write-Host "       Sidekick benötigt Python $($MinPythonVersion.Major).$($MinPythonVersion.Minor) oder höher." -ForegroundColor Yellow
    Write-Host "       Lade Python von folgender Webseite herunter und installiere es:" -ForegroundColor Yellow
    Write-Host "       $PythonOrgUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "       Achte darauf, beim Installieren die Option" -ForegroundColor Yellow
    Write-Host "       »Add Python to PATH« zu aktivieren." -ForegroundColor Yellow
    Write-Host ""
    Write-StatusFatal "Python-Installation erforderlich."
}

Write-StatusOk "Python gefunden: $pythonExe"

# ===================================================================
# 5. Venv erstellen
# ===================================================================
Write-Host ""
Write-StatusInfo "Erstelle Python-Venv in: $VenvDir"

# Prüfe ob venv bereits existiert und intakt ist
$venvPython = Join-Path -Path $VenvDir -ChildPath "Scripts\python.exe"
$venvPip    = Join-Path -Path $VenvDir -ChildPath "Scripts\pip.exe"

if ((Test-Path $venvPython) -and (Test-Path $venvPip)) {
    Write-StatusInfo "Venv existiert bereits – prüfe ob es funktioniert ..."
    try {
        $check = & $venvPython --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-StatusOk "Bestehendes Venv ist funktionsfähig."
            $reuseVenv = $true
        }
        else {
            Write-StatusInfo "Venv ist beschädigt – erstelle neu."
            $reuseVenv = $false
        }
    }
    catch {
        Write-StatusInfo "Venv ist beschädigt – erstelle neu."
        $reuseVenv = $false
    }
}
else {
    $reuseVenv = $false
}

if (-not $reuseVenv) {
    # Stelle sicher, dass das Elternverzeichnis existiert
    $parentDir = Split-Path -Parent $VenvDir -Resolve -ErrorAction SilentlyContinue
    if (-not $parentDir) {
        $parentDir = Split-Path -Parent $VenvDir
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    # Altes Venv entfernen, falls vorhanden
    if (Test-Path $VenvDir) {
        Write-StatusInfo "Entferne altes Venv ..."
        Remove-Item -Path $VenvDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-StatusInfo "Führe 'python -m venv' aus (ohne Symlinks – Windows-kompatibel) ..."
    try {
        # --without-symlinks ist Standard auf Windows, aber wir geben es explizit an
        & $pythonExe -m venv --without-pip $VenvDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-StatusFatal "Fehler beim Erstellen des Venv (Exit-Code: $LASTEXITCODE)."
        }

        # pip in venv installieren (get-pip.py ist robuster als --with-pip auf alten Python-Versionen)
        Write-StatusInfo "Installiere pip ins Venv ..."
        $getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
        try {
            # Versuche mit eingebautem ensurepip
            & $pythonExe -m ensurepip --upgrade 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "ensurepip fehlgeschlagen"
            }
        }
        catch {
            Write-StatusInfo "ensurepip nicht verfügbar – lade get-pip.py ..."
            # Lade get-pip.py herunter
            $getPipPath = Join-Path -Path $env:TEMP -ChildPath "get-pip.py"
            try {
                # PowerShell-basierter Download
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($getPipUrl, $getPipPath)
                & $pythonExe $getPipPath --quiet 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "get-pip.py fehlgeschlagen"
                }
                Remove-Item -Path $getPipPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-StatusFatal "pip-Installation fehlgeschlagen. Bitte Netzwerkverbindung prüfen."
            }
        }

        # Venv-Python testen
        if (-not (Test-Path $venvPython)) {
            Write-StatusFatal "Venv-Python nicht gefunden: $venvPython"
        }

        Write-StatusOk "Venv erfolgreich erstellt."
    }
    catch {
        Write-StatusFatal "Fehler beim Erstellen des Venv: $_"
    }
}

# ===================================================================
# 6. Venv aktivieren und Requirements installieren
# ===================================================================
Write-StatusInfo "Installiere Requirements aus: $RequirementsFile"

if (-not (Test-Path $RequirementsFile)) {
    Write-StatusError "Requirements-Datei nicht gefunden: $RequirementsFile"
    Write-Host "       Erwartet wird eine Datei 'requirements.txt' im Vendor-Verzeichnis." -ForegroundColor Yellow
    Write-Host "       VendorDir: $VendorDir" -ForegroundColor Yellow
    Write-StatusFatal "Requirements-Datei fehlt."
}

Write-StatusInfo "Aktualisiere pip im Venv ..."
try {
    & $venvPython -m pip install --upgrade pip --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-StatusInfo "pip-Update fehlgeschlagen – fahre mit vorhandener Version fort."
    }
    else {
        Write-StatusOk "pip aktualisiert."
    }
}
catch {
    Write-StatusInfo "pip-Update nicht möglich – fahre fort."
}

Write-StatusInfo "Installiere Python-Abhängigkeiten (pyyaml) ..."
try {
    $pipOutput = & $venvPython -m pip install -r "$RequirementsFile" --quiet 2>&1
    $pipExitCode = $LASTEXITCODE

    if ($pipExitCode -ne 0) {
        Write-Host ""
        Write-StatusError "pip-Installation fehlgeschlagen (Exit-Code: $pipExitCode)."
        Write-Host "       Ausgabe:" -ForegroundColor Yellow
        Write-Host "       $pipOutput" -ForegroundColor Yellow
        Write-StatusFatal "Requirements-Installation fehlgeschlagen."
    }

    # Prüfe ob pyyaml installiert wurde
    Write-StatusInfo "Prüfe Installation von pyyaml ..."
    try {
        $yamlCheck = & $venvPython -c "import yaml; print(yaml.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-StatusOk "pyyaml $($yamlCheck.Trim()) erfolgreich installiert."
        }
        else {
            Write-StatusError "pyyaml konnte nicht importiert werden."
        }
    }
    catch {
        Write-StatusError "pyyaml-Prüfung fehlgeschlagen: $_"
    }
}
catch {
    Write-StatusFatal "Requirements-Installation fehlgeschlagen: $_"
}

# ===================================================================
# 7. Zusammenfassung
# ===================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Zusammenfassung" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-StatusOk "PowerShell : $currentPSVersion"
if ($osInfo.OsName) {
    Write-StatusOk "Windows    : $($osInfo.OsName) ($osVersionStr)"
}
if ($webView2Version) {
    Write-StatusOk "WebView2   : Version $webView2Version"
}
else {
    Write-StatusError "WebView2   : NICHT VORHANDEN (Sidekick-Start nicht möglich)"
}
Write-StatusOk "Python     : $pythonExe"
Write-StatusOk "Venv       : $VenvDir"
Write-StatusOk "State-Verz.: $(Join-Path -Path $env:APPDATA -ChildPath 'Sidekick')"
Write-Host ""
Write-Host "  Venv-Python : $venvPython" -ForegroundColor Green
Write-Host "  Requirements: $(Get-Content $RequirementsFile | Out-String).Trim()" -ForegroundColor Green
Write-Host ""

# Falls WebView2 fehlt, nur warnen, nicht abbrechen
if (-not $webView2Version) {
    Write-Host "  !!! WICHTIG: WebView2 Runtime fehlt !!!" -ForegroundColor Yellow
    Write-Host "  Sidekick kann ohne WebView2 nicht gestartet werden." -ForegroundColor Yellow
    Write-Host "  Bitte installiere die WebView2 Evergreen Runtime von:" -ForegroundColor Yellow
    Write-Host "  $WebView2Url" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Bootstrap erfolgreich abgeschlossen!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

exit 0
