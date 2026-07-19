$ErrorActionPreference = 'Stop'

$releaseDirectory = Get-ChildItem -Path 'build/windows' -Directory -Recurse |
    Where-Object { $_.Name -eq 'Release' -and (Test-Path (Join-Path $_.FullName 'airmonlink_business_manager.exe')) } |
    Select-Object -First 1

if (-not $releaseDirectory) {
    throw 'The Windows Release directory was not found.'
}

$outputDirectory = 'dist'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$zipPath = Join-Path $outputDirectory 'Airmonlink-Business-Manager-1.0.1-build4-Windows-Portable.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $releaseDirectory.FullName '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Portable package created: $zipPath"
