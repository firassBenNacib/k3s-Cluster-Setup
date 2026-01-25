function Resolve-OutputDirectory {
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

    $leaf = Split-Path -Leaf $p
    $ext = [IO.Path]::GetExtension($leaf)
    if (-not [string]::IsNullOrWhiteSpace($ext)) {
        $bad = @(".yaml", ".yml", ".json", ".txt", ".log", ".cfg", ".conf", ".ps1", ".exe")
        if ($bad -contains $ext.ToLowerInvariant()) {
            throw "OutputDir must be a directory path; '$PathLike' looks like a file (extension '$ext')."
        }
    }

    if (Test-Path -LiteralPath $p) {
        $item = Get-Item -LiteralPath $p -ErrorAction Stop
        if (-not $item.PSIsContainer) {
            throw "OutputDir must be a directory: $p"
        }
    }
    else {
        New-SafeDirectory -Path $p
    }

    if (-not (Test-DirectoryWritable -Path $p)) {
        throw "OutputDir is not writable: $p"
    }
    return (Resolve-Path -LiteralPath $p).Path
}
