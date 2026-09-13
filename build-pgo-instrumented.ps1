$ErrorActionPreference = 'Stop'
$sdkRoot = Split-Path -Parent $PSScriptRoot
$vsRoot = 'C:\Program Files\Microsoft Visual Studio\18\Community'
$profileDir = Join-Path $PSScriptRoot 'pgo\raw'

& "$vsRoot\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
$env:PATH = "$vsRoot\VC\Tools\Llvm\x64\bin;" + $env:PATH
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
Get-ChildItem -LiteralPath $profileDir -Filter '*.profraw' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

Push-Location $PSScriptRoot
try {
    cmake --preset win-amd64-release "-DREXSDK_DIR=$sdkRoot" -DSW2_PGO=GENERATE
    if ($LASTEXITCODE -ne 0) { throw 'PGO instrumentation configuration failed.' }
    cmake --build --preset win-amd64-release -j 6
    if ($LASTEXITCODE -ne 0) { throw 'PGO instrumentation build failed.' }
} finally {
    Pop-Location
}
Write-Host 'Instrumented build ready. Train it with .\run-pgo-training.ps1'
