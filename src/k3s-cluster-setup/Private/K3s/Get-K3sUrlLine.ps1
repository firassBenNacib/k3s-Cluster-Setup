function Get-K3sUrlLine {
    param($EnvOut)
    if ($null -eq $EnvOut) { return $null }
    $envLines = @()
    foreach ($item in @($EnvOut)) {
        if ($item -is [System.Array]) {
            $envLines += @($item)
        }
        else {
            $envLines += $item
        }
    }
    $envLines = @($envLines | ForEach-Object { $_.ToString() })
    return ($envLines | Where-Object { $_ -match '^K3S_URL=' } | Select-Object -First 1)
}
