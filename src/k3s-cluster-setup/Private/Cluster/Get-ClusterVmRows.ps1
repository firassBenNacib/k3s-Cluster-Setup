function Get-ClusterVmRows {
    param(
        [Parameter(Mandatory=$true)]$Inventory,
        [Parameter(Mandatory=$true)][string[]]$VmNames
    )

    $rows = @($Inventory.Instances | ForEach-Object { ConvertTo-MultipassTableRow -Instance $_ })
    $byName = @{}
    foreach ($r in $rows) { $byName[$r.Name] = $r }

    $vmRows = @()
    foreach ($n in $VmNames) {
        if ($byName.ContainsKey($n)) {
            $vmRows += $byName[$n]
        }
        else {
            $vmRows += [pscustomobject]@{ Name = $n; State = 'Unknown' }
        }
    }
    return $vmRows
}

