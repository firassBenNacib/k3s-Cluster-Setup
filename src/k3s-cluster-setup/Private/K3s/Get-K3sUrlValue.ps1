function Get-K3sUrlValue {
    param($EnvOut)
    $line = Get-K3sUrlLine -EnvOut $EnvOut
    if (-not $line) { return $null }
    $m = [regex]::Match($line, '^K3S_URL=(.+)$')
    if (-not $m.Success) { return $null }
    $val = $m.Groups[1].Value.Trim()
    return $val.Trim("'`"")
}
