$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskApk = Join-Path $taskRoot 'build\app\outputs\flutter-apk\app-release.apk'
$taskOutput = Join-Path $taskRoot 'outputs\android'
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskDeliverable = Join-Path $taskOutput 'glb-teaching-0.1.1-arm64.apk'
$env:JAVA_HOME = 'D:\android\jbr'
$taskBuildTools = 'D:\sdk\Android-SDK@3.4.7.81308_20220424\build-tools\36.1.0'
$taskSignature = & (Join-Path $taskBuildTools 'apksigner.bat') verify --verbose $taskApk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
Push-Location $taskRoot
try {
    $taskBadging = & (Join-Path $taskBuildTools 'aapt.exe') dump badging 'build\app\outputs\flutter-apk\app-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect APK manifest' }
} finally { Pop-Location }
if (-not ($taskBadging -match "native-code: 'arm64-v8a'")) { throw 'Expected ARM64 APK' }
if (-not ($taskBadging -match "sdkVersion:'24'")) { throw 'Unexpected minimum Android version' }
if (-not ($taskBadging -match 'android.permission.RECORD_AUDIO')) { throw 'Microphone permission missing' }
if ($taskBadging -match 'application-debuggable') { throw 'Expected non-debuggable release APK' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskApk)
try {
    if ($taskZip.Entries | Where-Object { $_.FullName -match '(^|/)\.secrets/|tencent\.json$|cloud-preview\.json$|cos-assets\.json$|lighthouse-deploy' }) { throw 'Private configuration included in APK' }
    $taskModel = $taskZip.GetEntry('assets/flutter_assets/assets/avatar/models/storm-performance.glb')
    if ($null -eq $taskModel -or $taskModel.Length -ne 153334024) { throw 'Bundled Storm model missing or changed' }
    $taskModelStream = $taskModel.Open()
    $taskHasher = [System.Security.Cryptography.SHA256]::Create()
    try { $taskBundledModelHash = [Convert]::ToHexString($taskHasher.ComputeHash($taskModelStream)).ToLowerInvariant() } finally { $taskModelStream.Dispose(); $taskHasher.Dispose() }
    $taskOriginalModelHash = (Get-FileHash -LiteralPath (Join-Path $taskRoot 'assets\avatar\models\storm-performance.glb') -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($taskBundledModelHash -ne $taskOriginalModelHash) { throw 'Bundled model hash mismatch' }
    $taskSecrets = Get-Content -LiteralPath (Join-Path $taskRoot '.secrets\tencent.json') -Raw | ConvertFrom-Json
    foreach ($taskEntry in $taskZip.Entries) {
        if ($taskEntry.FullName -notmatch '\.(so|js|json|xml)$') { continue }
        $taskStream = $taskEntry.Open()
        $taskMemory = [System.IO.MemoryStream]::new()
        try {
            $taskStream.CopyTo($taskMemory)
            $taskText = [System.Text.Encoding]::UTF8.GetString($taskMemory.ToArray())
            foreach ($taskSecret in @($taskSecrets.secretId, $taskSecrets.secretKey)) {
                if ($taskSecret -and $taskText.Contains($taskSecret)) { throw 'Long-term API credential found in packaged code' }
            }
        } finally { $taskStream.Dispose(); $taskMemory.Dispose() }
    }
} finally { $taskZip.Dispose() }
Copy-Item -LiteralPath $taskApk -Destination $taskDeliverable -Force
$taskHash = (Get-FileHash -LiteralPath $taskDeliverable -Algorithm SHA256).Hash.ToLowerInvariant()
$taskReport = [ordered]@{
    version = '0.1.1+2'
    apk = $taskDeliverable
    bytes = (Get-Item -LiteralPath $taskDeliverable).Length
    sha256 = $taskHash
    abi = 'arm64-v8a'
    minAndroidApi = 24
    release = $true
    signatureVerified = $true
    signing = 'local test debug signing key; release build'
    microphonePermission = $true
    bundledStormModelSha256 = $taskBundledModelHash
    privateConfigurationAbsent = $true
    longTermSpeechCredentialsAbsent = $true
    realDeviceRun = $false
}
$taskReport | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskOutput 'apk-verification.json') -Encoding utf8
Write-Output ($taskReport | ConvertTo-Json)
