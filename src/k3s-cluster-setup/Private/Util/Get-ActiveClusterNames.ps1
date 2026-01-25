function Get-ActiveClusterNames {
    param([string]$MultipassCmd, [string[]]$Include = @())

    $names = @()
    if (-not [string]::IsNullOrWhiteSpace($MultipassCmd)) {
        try {
            $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
            $names += @($inv.Names)
        }
        catch {
            Write-NonFatalError $_
        }
    }
    if ($Include) {
        $names += @($Include)
    }
    return , @(Get-UniqueList -Items $names)
}
