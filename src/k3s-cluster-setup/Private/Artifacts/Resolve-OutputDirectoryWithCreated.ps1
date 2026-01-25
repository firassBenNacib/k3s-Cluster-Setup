function Resolve-OutputDirectoryWithCreated {
    param([string]$PathLike)

    $p = if ([string]::IsNullOrWhiteSpace($PathLike)) {
        (Get-Location).Path
    }
    else {
        (Expand-UserPath $PathLike).Trim()
    }
    if (-not [IO.Path]::IsPathRooted($p)) {
        $p = Join-Path (Get-Location).Path $p
    }

    $preExists = $false
    try {
        $preExists = (Test-Path -LiteralPath $p)
    }
    catch {
        $preExists = $false
    }

    $resolved = Resolve-OutputDirectory -PathLike $PathLike
    $created = (-not $preExists) -and (Test-Path -LiteralPath $resolved)

    return [pscustomobject]@{
        Path    = $resolved
        Created = $created
    }
}
