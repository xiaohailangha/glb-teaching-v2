param(
    [switch]$Dart,
    [string]$WorkingDirectory = 'scene-preview',
    [Parameter(Position=0,ValueFromRemainingArguments=$true)][string[]]$FlutterArgs
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = $env:SNOW_FLUTTER_TOOLS
if (-not $toolRoot) {
    $toolRoot = Join-Path ([IO.Path]::GetPathRoot($taskRoot)) 'sdk\snow-speaks'
}
$sdkRoot = Join-Path $toolRoot 'flutter-scene-sdk'
$executable = if ($Dart) { 'bin\dart.bat' } else { 'bin\flutter.bat' }
$launcher = Join-Path $sdkRoot $executable
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Flutter SDK unavailable at $sdkRoot. Set SNOW_FLUTTER_TOOLS to the directory containing flutter-scene-sdk."
}

$taskDrive = 'V:'
if (Test-Path -LiteralPath ($taskDrive + '\')) { throw 'V: is already in use; run only one Flutter wrapper at a time.' }
subst.exe $taskDrive $taskRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not map the scene validation workspace.' }

$taskExit = 1
$taskPushed = $false
$previousEnvironment = @{}
$taskEnvironment = @{
    PUB_CACHE = (Join-Path $toolRoot 'scene-pub-cache')
    ANDROID_HOME = 'D:\sdk\Android-SDK@3.4.7.81308_20220424'
    JAVA_HOME = 'D:\android\jbr'
    IMPELLERC = (Join-Path $sdkRoot 'bin\cache\artifacts\engine\windows-x64\impellerc.exe')
    GIT_CONFIG_COUNT = '1'
    GIT_CONFIG_KEY_0 = 'safe.directory'
    GIT_CONFIG_VALUE_0 = $sdkRoot.Replace('\','/')
}
try {
    foreach ($name in $taskEnvironment.Keys) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, $taskEnvironment[$name], 'Process')
    }
    $taskWorkingDirectory = if ([IO.Path]::IsPathRooted($WorkingDirectory)) { $WorkingDirectory } else { Join-Path 'V:\' $WorkingDirectory }
    Push-Location $taskWorkingDirectory
    $taskPushed = $true
    & $launcher @FlutterArgs
    $taskExit = $LASTEXITCODE
} finally {
    if ($taskPushed) { Pop-Location }
    foreach ($name in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
    subst.exe $taskDrive /D
}
exit $taskExit
