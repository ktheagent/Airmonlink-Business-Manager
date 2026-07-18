$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'windows')) {
    flutter config --enable-windows-desktop

    $temporaryProject = Join-Path ([System.IO.Path]::GetTempPath()) (
        'airmonlink-business-manager-windows-' + [System.Guid]::NewGuid().ToString('N')
    )

    try {
        flutter create `
            --platforms=windows `
            --org com.airmonlink `
            --project-name airmonlink_business_manager `
            $temporaryProject

        Copy-Item `
            -Path (Join-Path $temporaryProject 'windows') `
            -Destination 'windows' `
            -Recurse
    }
    finally {
        if (Test-Path $temporaryProject) {
            Remove-Item $temporaryProject -Recurse -Force
        }
    }
}

$mainCpp = 'windows/runner/main.cpp'
if (Test-Path $mainCpp) {
    $content = Get-Content $mainCpp -Raw
    $content = $content.Replace(
        'L"airmonlink_business_manager"',
        'L"Airmonlink Business Manager"'
    )
    Set-Content $mainCpp $content -NoNewline
}
