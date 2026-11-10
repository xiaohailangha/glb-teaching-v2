$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
try { Invoke-RestMethod http://127.0.0.1:5295/health -TimeoutSec 2 | Out-Null }
catch {
 if (-not (Test-Path (Join-Path $projectRoot 'scene-preview/build/web/index.html'))) { throw 'Run npm run build first' }
 Start-Process -FilePath (Get-Command node).Source -ArgumentList 'tools/serve-web.mjs' -WorkingDirectory $projectRoot -WindowStyle Hidden
}
Start-Process 'http://127.0.0.1:5295/scene/'
