function Invoke-K3sClusterSetupListAll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd
    )

    $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
    $rows = @($inv.Instances | ForEach-Object { ConvertTo-MultipassTableRow -Instance $_ })
    if (-not $rows -or @($rows).Count -eq 0) {
        Write-Host "No instances found." -ForegroundColor Yellow
        return
    }

    $wName = 24; $wState = 18; $wIPv4 = 20
    Write-Output (("{0,-$wName} {1,-$wState} {2,-$wIPv4} {3}" -f 'Name', 'State', 'IPv4', 'Image'))
    foreach ($r in ($rows | Sort-Object Name)) {
        Write-Output (("{0,-$wName} {1,-$wState} {2,-$wIPv4} {3}" -f $r.Name, $r.State, $r.IPv4, $r.Image))
    }
}
