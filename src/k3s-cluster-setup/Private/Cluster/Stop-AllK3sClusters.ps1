function Stop-AllK3sClusters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][string]$MultipassCmd,
        [switch]$Force,
        [switch]$Confirm
    )

    $mp = if ($MultipassCmd) { $MultipassCmd } else { Get-MultipassCmd }
    $inv = Get-ClusterInventory -MultipassCmd $mp
    $names = @((ConvertTo-Array $inv.Names))

    if ($names.Count -eq 0) {
        Write-Host "No clusters found." -ForegroundColor Yellow
        return
    }

    $changed = 0
    foreach ($name in $names) {
        if (Stop-K3sCluster -ClusterName $name -MultipassCmd $mp -Force -Confirm:$false) {
            $changed++
        }
    }

    if ($changed -eq 0) {
        Write-Host "All clusters are already stopped." -ForegroundColor Yellow
    }
}

