$previewRoot = Split-Path -Parent $PSScriptRoot
foreach ($service in @('tunnel', 'origin')) {
    $pidFile = Join-Path $previewRoot "work\tunnel\$service.pid"
    if (!(Test-Path -LiteralPath $pidFile)) { continue }
    $serviceId = [int](Get-Content -LiteralPath $pidFile -Raw).Trim()
    $serviceProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$serviceId" -ErrorAction SilentlyContinue
    if (!$serviceProcess) { continue }
    $belongsToPreview = if ($service -eq 'tunnel') {
        $serviceProcess.ExecutablePath -eq (Join-Path $previewRoot 'work\tunnel\cloudflared.exe') -or
        ($serviceProcess.Name -eq 'ssh.exe' -and $serviceProcess.CommandLine.Contains('nokey@localhost.run') -and
         $serviceProcess.CommandLine.Contains('80:127.0.0.1:5297') -and $serviceProcess.CommandLine.Contains('work/tunnel/known_hosts'))
    } else {
        $serviceProcess.Name -eq 'node.exe' -and $serviceProcess.CommandLine.Contains((Join-Path $previewRoot 'tools\public-preview.mjs'))
    }
    if ($belongsToPreview) { Stop-Process -Id $serviceId; Write-Output "Stopped $service ($serviceId)" }
}
