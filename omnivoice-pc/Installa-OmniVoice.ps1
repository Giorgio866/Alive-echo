# Installa OmniVoice (VoiceStudio) su Windows 10/11 x64.
# Scarica l'installer ufficiale, verifica il checksum, poi avvia l'installazione.
# Origine: https://github.com/debpalash/VoiceStudio/releases/tag/v0.5.0

$ErrorActionPreference = 'Stop'

$Version = '0.5.0'
$MsiName = "VoiceStudio_${Version}_x64_en-US.msi"
$Url = "https://github.com/debpalash/VoiceStudio/releases/download/v$Version/$MsiName"
$ExpectedSha256 = '5b4d6e136f90bee4544e7b5d595c31bf6a0e2eab30d79ad950f799dd29ecf864'
$MsiPath = Join-Path $env:TEMP $MsiName

Write-Host ""
Write-Host "========================================"
Write-Host "  OmniVoice per PC  (VoiceStudio $Version)"
Write-Host "========================================"
Write-Host ""
Write-Host "Serve Windows 10/11 a 64 bit e circa 10 GB liberi."
Write-Host "Al primo avvio l'app scarichera' i modelli vocali."
Write-Host ""

if (-not [Environment]::Is64BitOperatingSystem) {
    throw "Questo installer e' solo per Windows a 64 bit."
}

Write-Host "1/3  Scarico $MsiName ..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $Url -OutFile $MsiPath -UseBasicParsing

$ActualSha256 = (Get-FileHash -Path $MsiPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualSha256 -ne $ExpectedSha256) {
    throw "Checksum SHA256 non valido.`nAtteso: $ExpectedSha256`nTrovato: $ActualSha256"
}

Write-Host "2/3  Checksum OK."
Write-Host "3/3  Avvio l'installazione (accetta la richiesta di Windows se compare)..."
Write-Host ""

$process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $MsiPath, '/passive') -Wait -PassThru
if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
    throw "msiexec e' uscito con codice $($process.ExitCode). Prova a installare a mano il file:`n$MsiPath"
}

Write-Host ""
Write-Host "Installazione completata."
Write-Host "Apri il menu Start e cerca:  VoiceStudio"
Write-Host "oppure:  OmniVoice"
Write-Host ""
Write-Host "Il file scaricato resta qui (puoi cancellarlo):"
Write-Host "  $MsiPath"
Write-Host ""
