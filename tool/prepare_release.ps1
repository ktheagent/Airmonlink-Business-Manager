$ErrorActionPreference = 'Stop'

$dbSource = 'lib/services/database_service.dart'
$dbContent = Get-Content $dbSource -Raw
$dbContent = $dbContent.Replace('WHERE sku <> ""', "WHERE sku <> \'\'")
$dbContent = $dbContent.Replace('WHERE barcode <> ""', "WHERE barcode <> \'\'")
Set-Content $dbSource $dbContent -NoNewline

$constantsSource = 'lib/core/app_constants.dart'
$constantsContent = Get-Content $constantsSource -Raw
$constantsContent = $constantsContent.Replace('airmonlink_business_manager.db', 'airmonlink_business_manager_v2.db')
Set-Content $constantsSource $constantsContent -NoNewline

& "$PSScriptRoot/patch_title.ps1"

& "$PSScriptRoot/fix_ui_typos.ps1"
