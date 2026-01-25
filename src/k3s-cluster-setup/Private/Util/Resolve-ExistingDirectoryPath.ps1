function Resolve-ExistingDirectoryPath {
    param([string]$PathLike)

    if ([string]::IsNullOrWhiteSpace($PathLike)) {
        return ""
    }
    $p = (Expand-UserPath $PathLike).Trim()
    if ([string]::IsNullOrWhiteSpace($p)) {
        return ""
    }
    if (-not [IO.Path]::IsPathRooted($p)) {
        $p = Join-Path (Get-Location).Path $p
    }

    if (-not (Test-Path -LiteralPath $p)) {
        return ""
    }
    try {
        $item = Get-Item -LiteralPath $p -ErrorAction Stop
        if (-not $item.PSIsContainer) {
            return ""
        }
    }
    catch {
        return ""
    }

    try {
        return (Resolve-Path -LiteralPath $p).Path
    }
    catch {
        return $p
    }
}
