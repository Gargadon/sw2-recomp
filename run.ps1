$ErrorActionPreference = 'Stop'
$sdkRoot = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $PSScriptRoot 'out\build\win-amd64-release\samurai_warriors_2.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Run build.ps1 first.' }
$env:PATH = "$sdkRoot\bin;" + $env:PATH
$launchArgs = @($args)
# Boolean flags use --no-fullscreen, not the two tokens --fullscreen false.
if (!($launchArgs | Where-Object { $_ -eq '--fullscreen' -or $_ -like '--fullscreen=*' -or $_ -eq '--no-fullscreen' })) {
    $launchArgs += '--no-fullscreen'
}
# Explicit command-line options take precedence over these play defaults.
$defaults = [ordered]@{
    input_backend = 'xinput'
    log_level = 'warn'
}
foreach ($option in $defaults.Keys) {
    if (!($launchArgs | Where-Object { $_ -eq "--$option" -or $_ -like "--$option=*" })) {
        $launchArgs += @("--$option", $defaults[$option])
    }
}
Push-Location (Split-Path -Parent $exe)
try {
    & $exe --game_data_root "$sdkRoot\Samurai Warriors 2 (USA, Europe)" --gpu_plugin xenos @launchArgs
} finally {
    Pop-Location
}
