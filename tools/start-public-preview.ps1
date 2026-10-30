$ErrorActionPreference = 'Stop'
$previewRoot = Split-Path -Parent $PSScriptRoot
$previewWork = Join-Path $previewRoot 'work\tunnel'
$sessionFile = Join-Path $previewWork 'session.json'
$linkFile = Join-Path $previewWork 'access-link.txt'
$nodePath = (Get-Command node).Source
if ((Test-Path -LiteralPath $sessionFile) -and (Test-Path -LiteralPath $linkFile)) {
    $savedSession = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
    $savedProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($savedSession.pid)" -ErrorAction SilentlyContinue
    $tunnelIdFile = Join-Path $previewWork 'tunnel.pid'
    $savedTunnel = if (Test-Path -LiteralPath $tunnelIdFile) {
        $savedTunnelId = [int](Get-Content -LiteralPath $tunnelIdFile -Raw).Trim()
        Get-CimInstance Win32_Process -Filter "ProcessId=$savedTunnelId" -ErrorAction SilentlyContinue
    }
    if ($savedProcess -and $savedProcess.CommandLine.Contains((Join-Path $previewRoot 'tools\public-preview.mjs')) -and
        $savedTunnel -and $savedTunnel.ExecutablePath -eq (Join-Path $previewWork 'cloudflared.exe') -and
        [DateTimeOffset]$savedSession.expiresAt -gt [DateTimeOffset]::UtcNow) {
        & $nodePath (Join-Path $PSScriptRoot 'check-public-preview.mjs')
        if ($LASTEXITCODE -eq 0) {
            Get-Content -LiteralPath $linkFile
            exit 0
        }
    }
}
& (Join-Path $PSScriptRoot 'stop-public-preview.ps1')
try { $null = Invoke-WebRequest 'http://127.0.0.1:5296/health' -UseBasicParsing -TimeoutSec 3 }
catch {
    Start-Process -FilePath $nodePath -ArgumentList ('"' + (Join-Path $previewRoot 'server.mjs') + '"') -WorkingDirectory $previewRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $previewWork 'backend.out.log') -RedirectStandardError (Join-Path $previewWork 'backend.err.log')
}
$originProcess = Start-Process -FilePath $nodePath -ArgumentList ('"' + (Join-Path $PSScriptRoot 'public-preview.mjs') + '"') -WorkingDirectory $previewRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $previewWork 'origin.out.log') -RedirectStandardError (Join-Path $previewWork 'origin.err.log') -PassThru
Set-Content -LiteralPath (Join-Path $previewWork 'origin.pid') -Value $originProcess.Id
$tunnelProcess = Start-Process -FilePath (Join-Path $previewWork 'cloudflared.exe') -ArgumentList @('tunnel','--url','http://127.0.0.1:5297','--protocol','http2','--no-autoupdate') -WorkingDirectory $previewRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $previewWork 'tunnel.out.log') -RedirectStandardError (Join-Path $previewWork 'tunnel.err.log') -PassThru
Set-Content -LiteralPath (Join-Path $previewWork 'tunnel.pid') -Value $tunnelProcess.Id
$deadline = [DateTime]::UtcNow.AddSeconds(45)
do {
    Start-Sleep -Milliseconds 400
    $logText = Get-Content -LiteralPath (Join-Path $previewWork 'tunnel.err.log') -Raw -ErrorAction SilentlyContinue
    $publicOrigin = [regex]::Match([string]$logText, 'https://[a-z0-9-]+\.trycloudflare\.com').Value
} until ($publicOrigin -or [DateTime]::UtcNow -gt $deadline -or $tunnelProcess.HasExited)
if (!$publicOrigin) {
    & (Join-Path $PSScriptRoot 'stop-public-preview.ps1')
    throw 'Tunnel did not start. See work/tunnel/tunnel.err.log.'
}
Set-Content -LiteralPath (Join-Path $previewWork 'public-origin.txt') -Value $publicOrigin -NoNewline -Encoding ASCII
$previewSession = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
$accessLink = $publicOrigin + '/enter?key=' + $previewSession.token
Set-Content -LiteralPath $linkFile -Value $accessLink -NoNewline -Encoding ASCII
& $nodePath (Join-Path $PSScriptRoot 'check-public-preview.mjs')
if ($LASTEXITCODE -ne 0) {
    throw 'Tunnel URL was allocated but public verification failed. Do not share it yet; run this script again to recover.'
}
Write-Output $accessLink
