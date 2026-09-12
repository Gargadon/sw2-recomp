param(
    [string]$GeneratedDir = (Join-Path $PSScriptRoot 'generated\sw2xl_us')
)

$ErrorActionPreference = 'Stop'
$marker = 'DEFINE_REX_FUNC(sub_8819C710)'
$source = Get-ChildItem -LiteralPath $GeneratedDir -Filter '*_recomp.*.cpp' |
    Where-Object { Select-String -LiteralPath $_.FullName -SimpleMatch $marker -Quiet } |
    Select-Object -First 1

if (!$source) { throw "Could not find $marker under $GeneratedDir." }

$text = Get-Content -LiteralPath $source.FullName -Raw
$start = $text.IndexOf($marker)
$end = $text.IndexOf('DEFINE_REX_FUNC(', $start + $marker.Length)
if ($end -lt 0) { $end = $text.Length }
$functionText = $text.Substring($start, $end - $start)
$labels = @(
    'loc_8819C760', 'sub_8819C798', 'sub_88198C98',
    'sub_8819F6D8', 'sub_8819F710', 'sub_8819D528',
    'sub_8819AD00', 'sub_881A4040', 'sub_8819C7D0'
)

$changed = $false
for ($index = 1; $index -lt $labels.Count; $index++) {
    $oldCase = "case ${index}:`n`t`t$($labels[$index])"
    $scaled = $index * 4
    $newCase = "case ${scaled}:`n`t`t$($labels[$index])"
    if ($functionText.Contains($newCase)) { continue }
    if (!$functionText.Contains($oldCase)) {
        throw "The XL switch case for $($labels[$index]) no longer matches the expected output."
    }
    $functionText = $functionText.Replace($oldCase, $newCase)
    $changed = $true
}

if ($changed) {
    $text = $text.Remove($start, $end - $start).Insert($start, $functionText)
    [IO.File]::WriteAllText($source.FullName, $text, [Text.UTF8Encoding]::new($false))
    Write-Host 'Scaled XL dispatch cases at guest address 0x8819C758.'
}
