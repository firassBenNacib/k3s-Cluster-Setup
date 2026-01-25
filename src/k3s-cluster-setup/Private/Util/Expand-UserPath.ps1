function Expand-UserPath {
    param([string]$p)
    if ([string]::IsNullOrWhiteSpace($p)) {
        return $p
    }

    $p = $p.Trim()
    $p = [Environment]::ExpandEnvironmentVariables($p)

    if ($p -match '^\s*~([\\/]|$)') {
        $homeDir = $HOME
        $tail = ($p -replace '^\s*~', '')
        if ([string]::IsNullOrWhiteSpace($tail)) {
            return $homeDir
        }
        return (Join-Path $homeDir ($tail.TrimStart('\', '/')))
    }

    return $p
}
