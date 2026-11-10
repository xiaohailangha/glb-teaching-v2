$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
 & ./tools/flutter-scene.ps1 pub get
 if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed' }
 & ./tools/flutter-scene.ps1 build web --release --no-pub --base-href=/scene/ --no-web-resources-cdn --no-wasm-dry-run
 if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
 node tools/package-scene-web.mjs
 if ($LASTEXITCODE -ne 0) { throw 'Web packaging failed' }
} finally { Pop-Location }
