function Resolve-LocalPath {
    param([string]$PathLike, [string]$DefaultName)

    $p0 = if ([string]::IsNullOrWhiteSpace($PathLike)) {
        $DefaultName
    }
    else {
        $PathLike
    }
    $p1 = Expand-UserPath $p0

    if ([string]::IsNullOrWhiteSpace($p1)) {
        return $p1
    }

    if (Test-Path -LiteralPath $p1) {
        return (Resolve-Path -LiteralPath $p1).Path
    }

    $p2 = Add-YamlExtension -PathLike $p1
    if ([IO.Path]::IsPathRooted($p2)) {
        return $p2
    }

    if ($p2 -match '[\\/]' -or $p2.StartsWith('.')) {
        return (Join-Path (Get-Location).Path $p2)
    }

    return (Join-Path (Get-Location).Path $p2)
}
