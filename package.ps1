param(
    [string]$OutputDir = (Join-Path $PSScriptRoot 'dist\sw2xl-test-bundle'),
    [switch]$SkipGameData,
    [switch]$SkipUserData,
    [switch]$Zip,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$sdkRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $PSScriptRoot 'out\build\win-amd64-release'
$gameDir = Join-Path $sdkRoot 'Samurai Warriors 2 (USA, Europe)'
$output = [IO.Path]::GetFullPath($OutputDir)
$required = @('samurai_warriors_2.exe', 'samurai_warriors_2_SW2XL_US.dll', 'rexruntime.dll', 'rexgpu-xenos.dll')

foreach ($file in $required) {
    if (!(Test-Path -LiteralPath (Join-Path $buildDir $file))) {
        throw "Missing $file. Run .\build.ps1 first."
    }
}
if (Test-Path -LiteralPath $output) {
    if (!$Force) { throw "Output already exists: $output (use -Force to replace it)." }
    Remove-Item -LiteralPath $output -Recurse -Force
}
New-Item -ItemType Directory -Path $output | Out-Null
foreach ($file in $required) {
    Copy-Item -LiteralPath (Join-Path $buildDir $file) -Destination $output
}

if (!$SkipGameData) {
    if (!(Test-Path -LiteralPath $gameDir)) { throw "Game data was not found at $gameDir." }
    Copy-Item -LiteralPath $gameDir -Destination (Join-Path $output 'game') -Recurse
}
if (!$SkipUserData) {
    $userData = Join-Path $PSScriptRoot 'userdata'
    if (Test-Path -LiteralPath $userData) {
        Copy-Item -LiteralPath $userData -Destination (Join-Path $output 'userdata') -Recurse
    }
}
New-Item -ItemType Directory -Path (Join-Path $output 'cache') -Force | Out-Null

$launcher = @'
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$exe = Join-Path $root 'samurai_warriors_2.exe'
$game = Join-Path $root 'game'
if (!(Test-Path -LiteralPath (Join-Path $game 'default.xex'))) {
    throw 'Game data is missing from the bundle\game directory.'
}
$launchArgs = @($args)
if (!($launchArgs | Where-Object { $_ -eq '--fullscreen' -or $_ -like '--fullscreen=*' -or $_ -eq '--no-fullscreen' })) {
    $launchArgs += '--no-fullscreen'
}
if (!($launchArgs | Where-Object { $_ -eq '--mnk_mode' -or $_ -like '--mnk_mode=*' -or $_ -eq '--no-mnk_mode' })) {
    $launchArgs += '--mnk_mode'
}
$defaults = [ordered]@{
    input_backend = 'xinput'
    log_level = 'warn'
    render_target_path_d3d12 = 'rtv'
    user_data_root = (Join-Path $root 'userdata')
    cache_root = (Join-Path $root 'cache')
}
foreach ($option in $defaults.Keys) {
    if (!($launchArgs | Where-Object { $_ -eq "--$option" -or $_ -like "--$option=*" })) {
        $launchArgs += @("--$option", $defaults[$option])
    }
}
Push-Location $root
try {
    & $exe --game_data_root $game --gpu_plugin xenos @launchArgs
} finally {
    Pop-Location
}
'@
[IO.File]::WriteAllText((Join-Path $output 'run.ps1'), $launcher, [Text.UTF8Encoding]::new($false))

$notes = @'
# Samurai Warriors 2: Xtreme Legends test bundle

Run `run.ps1` from PowerShell. Runtime data, DLC, saves, shader cache, and logs
remain inside this directory. The bundle contains local game data and is meant
for private testing.
'@
[IO.File]::WriteAllText((Join-Path $output 'README.md'), $notes, [Text.UTF8Encoding]::new($false))

if ($Zip) {
    $zipPath = "$output.zip"
    if (Test-Path -LiteralPath $zipPath) {
        if (!$Force) { throw "Archive already exists: $zipPath (use -Force to replace it)." }
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -LiteralPath $output -DestinationPath $zipPath -CompressionLevel Fastest
    Write-Host "Created archive: $zipPath"
}
Write-Host "Created portable test bundle: $output"
