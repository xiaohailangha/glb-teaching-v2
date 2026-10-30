param([Parameter(ValueFromRemainingArguments=$true)][string[]]$FlutterArgs)
$projectRoot = Split-Path -Parent $PSScriptRoot
$mappingCreated = $false
$temporaryDrive = 'V:'
if (Test-Path -LiteralPath ($temporaryDrive + '\')) {
    throw 'V: is already in use. Change temporaryDrive in tools/flutter.ps1 to a free drive.'
}
subst.exe $temporaryDrive $projectRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not create temporary ASCII build path.' }
$mappingCreated = $true
$env:GIT_CONFIG_COUNT='1'
$env:GIT_CONFIG_KEY_0='safe.directory'
$env:GIT_CONFIG_VALUE_0='D:/flutter'
$env:ANDROID_HOME='D:\sdk\Android-SDK@3.4.7.81308_20220424'
$env:JAVA_HOME='D:\android\jbr'
$flutterExitCode = 1
Push-Location ($temporaryDrive + '\')
try {
    & 'D:\flutter\bin\flutter.bat' @FlutterArgs
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
    if ($mappingCreated) { subst.exe $temporaryDrive /D }
}
exit $flutterExitCode
