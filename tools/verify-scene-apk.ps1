$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskApk = Join-Path $taskRoot 'scene-preview\build\app\outputs\flutter-apk\app-release.apk'
$taskOutput = Join-Path $taskRoot 'outputs\android-scene'
$taskTools = 'D:\sdk\Android-SDK@3.4.7.81308_20220424\build-tools\36.1.0'
$env:JAVA_HOME = 'D:\android\jbr'
& (Join-Path $taskTools 'apksigner.bat') verify --verbose $taskApk
if ($LASTEXITCODE -ne 0) { throw 'Signature verification failed' }
Push-Location $taskRoot
try { $taskBadging = & (Join-Path $taskTools 'aapt.exe') dump badging 'scene-preview/build/app/outputs/flutter-apk/app-release.apk' }
finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect manifest' }
foreach ($taskRequired in @("name='com.local.glbscene.snow_speaks'", "versionCode='5'", "versionName='0.2.0'", "native-code: 'arm64-v8a'", 'android.permission.RECORD_AUDIO')) {
    if (-not ($taskBadging -match [regex]::Escape($taskRequired))) { throw "Manifest check failed: $taskRequired" }
}
if ($taskBadging -match 'application-debuggable') { throw 'APK is debuggable' }
Push-Location $taskRoot
try { $taskManifest = & (Join-Path $taskTools 'aapt.exe') dump xmltree 'scene-preview/build/app/outputs/flutter-apk/app-release.apk' AndroidManifest.xml }
finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect packaged manifest XML' }
if (-not ($taskManifest -match 'screenOrientation.*0x6')) { throw 'Landscape orientation missing' }
if (-not ($taskManifest -match 'io.flutter.embedding.android.EnableFlutterGPU')) { throw 'Flutter GPU opt-in missing' }
$taskMinSdk = [int]([regex]::Match(($taskBadging -join "`n"), "sdkVersion:'(\d+)'").Groups[1].Value)
if ($taskMinSdk -gt 31) { throw 'APK cannot run on the target Android 12 phone' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskApk)
function Get-EntryHash($entry) {
    $stream = $entry.Open(); $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant() }
    finally { $stream.Dispose(); $hasher.Dispose() }
}
try {
    if ($taskZip.Entries | Where-Object { $_.FullName -match '(^|/)\.secrets/|tencent\.json$|cloud-preview\.json$|cos-assets\.json$|lighthouse-deploy' }) { throw 'Private configuration in APK' }
    $taskModels = @($taskZip.Entries | Where-Object { $_.FullName -match '/scene\.storm-performance\..*\.fsceneb$' })
    if ($taskModels.Count -ne 1 -or $taskModels[0].Length -lt 50000000) { throw 'Embedded Scene model missing' }
    $taskModelHash = Get-EntryHash $taskModels[0]
    $taskSource = Join-Path $taskRoot ('scene-preview\flutter_scene_generated\' + $taskModels[0].Name)
    if ($taskModelHash -ne (Get-FileHash -LiteralPath $taskSource).Hash.ToLowerInvariant()) { throw 'Model hash mismatch' }
    $taskAudioCount = 0
    foreach ($taskFile in Get-ChildItem (Join-Path $taskRoot 'scene-preview\assets\avatar\audio') -File) {
        $taskEntry = $taskZip.GetEntry('assets/flutter_assets/assets/avatar/audio/' + $taskFile.Name)
        if ($null -eq $taskEntry -or (Get-EntryHash $taskEntry) -ne (Get-FileHash -LiteralPath $taskFile.FullName).Hash.ToLowerInvariant()) { throw "Audio asset mismatch: $($taskFile.Name)" }
        $taskAudioCount++
    }
    $taskSecrets = Get-Content -LiteralPath (Join-Path $taskRoot '.secrets\tencent.json') -Raw | ConvertFrom-Json
    foreach ($taskEntry in $taskZip.Entries) {
        if ($taskEntry.FullName -notmatch '\.(so|js|json|xml|dex)$') { continue }
        $taskStream = $taskEntry.Open(); $taskMemory = [System.IO.MemoryStream]::new()
        try {
            $taskStream.CopyTo($taskMemory)
            $taskText = [System.Text.Encoding]::UTF8.GetString($taskMemory.ToArray())
            foreach ($taskSecret in @($taskSecrets.secretId, $taskSecrets.secretKey)) {
                if ($taskSecret -and $taskText.Contains($taskSecret)) { throw 'Long-term API credential in package' }
            }
        } finally { $taskStream.Dispose(); $taskMemory.Dispose() }
    }
} finally { $taskZip.Dispose() }
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskDeliverable = Join-Path $taskOutput 'glb-scene-0.2.0-r5-arm64.apk'
Copy-Item -LiteralPath $taskApk -Destination $taskDeliverable -Force
$taskReport = [ordered]@{
    version = '0.2.0+5'; applicationId = 'com.local.glbscene.snow_speaks'; abi = 'arm64-v8a'
    minAndroidApi = $taskMinSdk; landscape = $true; flutterGpuOptIn = $true
    bytes = (Get-Item -LiteralPath $taskDeliverable).Length
    sha256 = (Get-FileHash -LiteralPath $taskDeliverable).Hash.ToLowerInvariant()
    bundledModelSha256 = $taskModelHash; verifiedAudioFiles = $taskAudioCount
    signatureVerified = $true; signing = 'local debug key, non-debuggable release test build'
    privateConfigurationAbsent = $true; longTermCredentialsAbsent = $true
    userPhoneWebMotionAndVoiceAccepted = $true; nativeDeviceVerified = $false
}
$taskReport | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskOutput 'verification.json') -Encoding utf8
$taskReport | ConvertTo-Json
