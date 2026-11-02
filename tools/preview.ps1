$projectRoot = Split-Path -Parent $PSScriptRoot
$previewUrl = 'http://localhost:5296/'
try {
    $health = Invoke-RestMethod -Uri ($previewUrl + 'health') -TimeoutSec 2
} catch {
    $nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
    if (-not $nodePath) {
        $nodePath = 'C:\Users\dyw\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'scene-preview\build\web\index.html'))) {
        throw 'Build Flutter Web first: tools/flutter-scene.ps1 build web --release --no-web-resources-cdn --base-href=/scene/'
    }
    & $nodePath (Join-Path $projectRoot 'tools/prepare-local-storage.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Local storage preparation failed' }
    Start-Process -FilePath $nodePath -ArgumentList 'server.mjs' -WorkingDirectory $projectRoot -WindowStyle Hidden
    $ready = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri ($previewUrl + 'health') -TimeoutSec 1
            $ready = $true
            break
        } catch { Start-Sleep -Milliseconds 250 }
    }
    if (-not $ready) { throw 'Preview server did not start on port 5296.' }
}
Start-Process ($previewUrl + 'scene/')
