param(
    [switch]$Dart,
    [string]$WorkingDirectory = 'scene-preview',
    [Parameter(Position=0,ValueFromRemainingArguments=$true)][string[]]$FlutterArgs
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskDrive = 'V:'
if (Test-Path -LiteralPath ($taskDrive + '\')) { throw 'V: is already in use; run only one Flutter wrapper at a time.' }
subst.exe $taskDrive $taskRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not map the scene validation workspace.' }
$taskExit = 1
$taskPreviousPubCache = $env:PUB_CACHE
$env:PUB_CACHE = 'V:\work\scene-pub-cache'
$env:ANDROID_HOME = 'D:\sdk\Android-SDK@3.4.7.81308_20220424'
$env:JAVA_HOME = 'D:\android\jbr'
$env:IMPELLERC = 'V:\work\flutter-scene-sdk\bin\cache\artifacts\engine\windows-x64\impellerc.exe'
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = ($taskRoot + '\work\flutter-scene-sdk').Replace('\','/')
$taskPushed = $false
try {
    Push-Location (Join-Path 'V:\' $WorkingDirectory)
    $taskPushed = $true
    if ($Dart) { & 'V:\work\flutter-scene-sdk\bin\dart.bat' @FlutterArgs }
    else { & 'V:\work\flutter-scene-sdk\bin\flutter.bat' @FlutterArgs }
    $taskExit = $LASTEXITCODE
} finally {
    if ($taskPushed) { Pop-Location }
    $env:PUB_CACHE = $taskPreviousPubCache
    subst.exe $taskDrive /D
}
exit $taskExit
