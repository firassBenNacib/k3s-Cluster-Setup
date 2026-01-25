function Get-K3sClusters {
    [CmdletBinding()]
    param(
        [string]$MultipassCmd = "",
        [switch]$Raw
    )

    if ([string]::IsNullOrWhiteSpace($MultipassCmd)) {
        $MultipassCmd = Get-MultipassCmd
    }

    $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
    $names = @($inv.Names)

    if (-not $names -or $names.Count -eq 0) {
        return @()
    }

    foreach ($c in $names) {
        $entry = $inv.Clusters[$c]
        $servers = @(Get-UniqueList -Items @($entry.Servers))
        $agents = @(Get-UniqueList -Items @($entry.Agents))

        $obj = [pscustomobject]@{
            PSTypeName  = 'K3s.Multipass.Cluster'
            ClusterName = $c
            ServerCount = $servers.Count
            AgentCount  = $agents.Count
            Servers     = if ($servers.Count -gt 0) { $servers -join ', ' } else { '' }
            Agents      = if ($agents.Count -gt 0) { $agents -join ', ' } else { '' }
        }

        if ($Raw) {
            Add-Member -InputObject $obj -NotePropertyName ServerNames -NotePropertyValue $servers -Force
            Add-Member -InputObject $obj -NotePropertyName AgentNames  -NotePropertyValue $agents  -Force
        }

        $obj
    }
}
