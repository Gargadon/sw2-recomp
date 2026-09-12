$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run.ps1') --render_target_path_d3d12 rtv @args
exit $LASTEXITCODE
