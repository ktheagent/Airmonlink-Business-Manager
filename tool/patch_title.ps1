$path = 'windows/runner/main.cpp'
$content = Get-Content $path -Raw
$content = $content.Replace('L"airmonlink_business_manager"', 'L"Airmonlink Business Manager"')
Set-Content $path $content -NoNewline
