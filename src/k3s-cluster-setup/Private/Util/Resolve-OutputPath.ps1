function Resolve-OutputPath {
    param(
        [string]$PathLike,
        [string]$DefaultName,
        [Parameter(Mandatory)][string]$BaseDir,
        [switch]$AddYamlExtension
    )

    $baseFull = (Resolve-Path -LiteralPath $BaseDir).Path
    $pRaw = if ([string]::IsNullOrWhiteSpace($PathLike)) {
        $DefaultName
    }
    else {
        $PathLike.Trim()
    }
    $p = Expand-UserPath $pRaw
    if ($AddYamlExtension) {
        $p = Add-YamlExtension -PathLike $p
    }

    $hasDir = ($p -match '[\\/]' -or $p.StartsWith('.'))

    if ([IO.Path]::IsPathRooted($p)) {
        $out = $p
    }
    elseif ($hasDir) {
        $out = Join-Path (Get-Location).Path $p
    }
    else {
        $out = Join-Path $baseFull $p
    }

    try {
        $out = [IO.Path]::GetFullPath($out)
    }
    catch {
        Write-NonFatalError $_
    }

    $dir = Split-Path -Parent $out
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-SafeDirectory -Path $dir
    }
    return $out
}
