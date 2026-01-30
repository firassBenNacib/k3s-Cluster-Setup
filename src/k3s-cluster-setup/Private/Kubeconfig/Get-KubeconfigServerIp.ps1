function Get-KubeconfigServerIp {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $txt = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $m = [regex]::Match($txt, 'server:\s*https://([^:/\s]+)(?::\d+)?', 'IgnoreCase')
        if ($m.Success) { return $m.Groups[1].Value }
    } catch { }
    return $null
}
