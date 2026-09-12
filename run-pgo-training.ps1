$ErrorActionPreference = 'Stop'
$profileDir = Join-Path $PSScriptRoot 'pgo\raw'
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

$previousProfileFile = $env:LLVM_PROFILE_FILE
$env:LLVM_PROFILE_FILE = Join-Path $profileDir 'sw2-%m-%p.profraw'
$gameExitCode = 0
try {
    & (Join-Path $PSScriptRoot 'run.ps1') @args
    $gameExitCode = $LASTEXITCODE
} finally {
    $env:LLVM_PROFILE_FILE = $previousProfileFile
}
exit $gameExitCode
