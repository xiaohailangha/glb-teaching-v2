$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
try { Invoke-RestMethod http://127.0.0.1:5295/health -TimeoutSec 2 | Out-Null }
catch {
 $webOutput = & node (Join-Path $PSScriptRoot 'local-paths.mjs')
 if ($LASTEXITCODE -ne 0 -or -not $webOutput -or -not (Test-Path -LiteralPath (Join-Path $webOutput 'index.html'))) { throw 'Run npm run build first' }
 Start-Process -FilePath (Get-Command node).Source -ArgumentList 'tools/serve-web.mjs' -WorkingDirectory $projectRoot -WindowStyle Hidden
}
Start-Process 'http://127.0.0.1:5295/scene/'
