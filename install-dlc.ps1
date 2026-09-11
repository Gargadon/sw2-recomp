param([string]$DlcRoot = 'D:\Samurai Warriors 2 XL')
$ErrorActionPreference = 'Stop'
$dlcRoot = $DlcRoot
if (!(Test-Path -LiteralPath $dlcRoot -PathType Container)) {
    throw "DLC directory not found: $dlcRoot"
}
& "$PSScriptRoot\run.ps1" --sw2_dlc_root ([IO.Path]::GetFullPath($dlcRoot)) --log_level warn
if ($LASTEXITCODE -ne 0) { throw "DLC installation failed with exit code $LASTEXITCODE." }
