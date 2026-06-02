@echo off
title Git Push v1.03
cd /d C:\HermesPortable\cids-hermes-webui
echo Pushe v1.03-Integration zu GitHub...
echo.
git push origin main
echo.
if %errorlevel%==0 (
    echo Erfolgreich gepusht!
) else (
    echo Fehler beim Pushen. Netzwerk/Firewall prüfen.
)
echo.
pause
