param(
    [Parameter(Mandatory=$true)][string]$CsvPath,
    [Parameter(Mandatory=$true)][string]$AppId
)
$projectRoot = Split-Path -Parent $PSScriptRoot
$privateDirectory = Join-Path $projectRoot '.secrets'
if ($AppId -notmatch '^\d+$') { throw 'AppId must be numeric.' }
$rows = @(Import-Csv -LiteralPath $CsvPath)
if ($rows.Count -ne 1) { throw 'Expected a CSV containing exactly one project account.' }
$row = $rows[0]
$idField = $row.PSObject.Properties | Where-Object { $_.Name -match '^SecretId$' }
$keyField = $row.PSObject.Properties | Where-Object { $_.Name -match '^SecretKey$' }
if (-not $idField.Value -or -not $keyField.Value) { throw 'CSV must contain SecretId and SecretKey columns.' }
New-Item -ItemType Directory -Path $privateDirectory -Force | Out-Null
$config = @{appId=$AppId;secretId=$idField.Value;secretKey=$keyField.Value}
$config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $privateDirectory 'tencent.json') -Encoding utf8
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $privateDirectory /inheritance:r /grant:r "${currentUser}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null
Write-Output 'Tencent credentials saved in the server-only project configuration. Values are not printed.'
