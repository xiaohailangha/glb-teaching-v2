$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
$buildLock = $null
try {
    $webOutput = & node tools/local-paths.mjs
    if ($LASTEXITCODE -ne 0 -or -not $webOutput) { throw 'Could not locate the web output directory' }
    $outputRoot = Split-Path -Parent $webOutput
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    $outputRoot = (Resolve-Path -LiteralPath $outputRoot).ProviderPath
    if ((Get-Item -LiteralPath $outputRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "The output directory is redirected: $outputRoot"
    }
    $buildLock = [IO.File]::Open((Join-Path $outputRoot 'build.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $webOutput = Join-Path $outputRoot 'web'
    $stamp = [guid]::NewGuid().ToString('N')
    $candidate = Join-Path $outputRoot "web-build-$stamp"
    $previous = Join-Path $outputRoot "web-previous-$stamp"

    try {
        & ./tools/flutter-scene.ps1 pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed' }
        & ./tools/flutter-scene.ps1 build web --release --no-pub --base-href=/scene/ --no-web-resources-cdn --no-wasm-dry-run "--output=$candidate"
        if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }

        if (Test-Path -LiteralPath $webOutput) {
            Get-ChildItem -LiteralPath $webOutput -File -Filter 'index.*.html' |
                Where-Object { $_.Name -match '^index\.[a-f0-9]{16}\.html$' } |
                ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $candidate }
        }
        & node tools/package-scene-web.mjs scene-preview $candidate
        if ($LASTEXITCODE -ne 0) { throw 'Web packaging failed' }

        if (Test-Path -LiteralPath $webOutput) {
            Move-Item -LiteralPath $webOutput -Destination $previous
        }
        try {
            Move-Item -LiteralPath $candidate -Destination $webOutput
        } catch {
            if (Test-Path -LiteralPath $previous) {
                Move-Item -LiteralPath $previous -Destination $webOutput
            }
            throw
        }
    } finally {
        foreach ($temporary in @($candidate, $previous)) {
            if (-not (Test-Path -LiteralPath $temporary)) { continue }
            $item = Get-Item -LiteralPath $temporary
            if ($item.FullName -ne $temporary -or $item.Parent.FullName -ne $outputRoot -or
                ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "Unexpected build staging directory: $temporary"
            }
            if ($temporary -eq $previous -and -not (Test-Path -LiteralPath $webOutput)) { continue }
            Remove-Item -LiteralPath $temporary -Recurse -Force
        }
    }
} finally {
    if ($buildLock) { $buildLock.Dispose() }
    Pop-Location
}
