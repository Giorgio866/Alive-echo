@echo off
title OmniVoice per PC
cd /d "%~dp0"
echo.
echo  Installazione OmniVoice (VoiceStudio) su questo PC...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Installa-OmniVoice.ps1"
if errorlevel 1 (
  echo.
  echo  Qualcosa e' andato storto. Puoi anche scaricare l'installer ufficiale:
  echo  https://github.com/debpalash/VoiceStudio/releases/download/v0.5.0/VoiceStudio_0.5.0_x64_en-US.msi
  echo.
)
pause
