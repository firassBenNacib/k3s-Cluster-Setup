function Invoke-K3sClusterSetupList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd
    )

    $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
    $clusters = @($inv.Clusters.Keys)
    if (-not $clusters -or $clusters.Count -eq 0) {
        Write-Host "No clusters found." -ForegroundColor Yellow
        return
    }

    $instByName = @{}
    foreach ($vm in @($inv.Instances)) {
        if ($vm -and $vm.name) { $instByName[[string]$vm.name] = $vm }
    }

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($cn in ($clusters | Sort-Object)) {
        $c = $inv.Clusters[$cn]
        $servers = @($c.servers)
        $agents = @($c.agents)

        $states = @()
        foreach ($n in @($servers + $agents)) {
            if ($instByName.ContainsKey($n) -and $instByName[$n] -and $instByName[$n].state) {
                $states += [string]$instByName[$n].state
            }
            else {
                $states += 'Unknown'
            }
        }

        $state = if (-not $states -or $states.Count -eq 0) {
            'Unknown'
        }
        elseif ($states -contains 'Unknown') {
            'Unknown'
        }
        else {
            $uniq = @($states | Select-Object -Unique)
            if ($uniq.Count -eq 1) { $uniq[0] } else { 'Mixed' }
        }

        $serversStr = ($servers -join ', ')
        $agentsStr = ($agents -join ', ')

        $rows.Add([pscustomobject]@{
                Cluster     = $cn
                State       = $state
                ServerCount = $servers.Count
                AgentCount  = $agents.Count
                Servers     = $serversStr
                Agents      = $agentsStr
            }) | Out-Null
    }

    $maxCluster = ($rows | ForEach-Object { $_.Cluster.Length } | Measure-Object -Maximum).Maximum
    $maxState = ($rows | ForEach-Object { $_.State.Length } | Measure-Object -Maximum).Maximum
    $maxServers = ($rows | ForEach-Object { $_.Servers.Length } | Measure-Object -Maximum).Maximum
    $maxAgents = ($rows | ForEach-Object { $_.Agents.Length } | Measure-Object -Maximum).Maximum

    if (-not $maxCluster) { $maxCluster = 0 }
    if (-not $maxState) { $maxState = 0 }
    if (-not $maxServers) { $maxServers = 0 }
    if (-not $maxAgents) { $maxAgents = 0 }

    $maxServers = [Math]::Min([int]$maxServers, 40)
    $maxAgents = [Math]::Min([int]$maxAgents, 40)

    $wCluster = [Math]::Max([int]'ClusterName'.Length, [int]$maxCluster)
    $wState = [Math]::Max([int]'State'.Length, [int]$maxState)
    $wSrv = [Math]::Max([int]'ServerCount'.Length, 2)
    $wAgt = [Math]::Max([int]'AgentCount'.Length, 2)
    $wServers = [Math]::Max([int]'Servers'.Length, [int]$maxServers)
    $wAgents = [Math]::Max([int]'Agents'.Length, [int]$maxAgents)

    Write-Output (("{0,-$wCluster}   {1,-$wState}   {2,-$wSrv}   {3,-$wAgt}   {4,-$wServers}   {5}" -f
            'ClusterName', 'State', 'ServerCount', 'AgentCount', 'Servers', 'Agents'))

    foreach ($row in $rows) {
        Write-Output (("{0,-$wCluster}   {1,-$wState}   {2,-$wSrv}   {3,-$wAgt}   {4,-$wServers}   {5}" -f
                $row.Cluster,
                (Get-TruncatedString -Value $row.State -Width $wState),
                $row.ServerCount,
                $row.AgentCount,
                (Get-TruncatedString -Value $row.Servers -Width $wServers),
                (Get-TruncatedString -Value $row.Agents -Width $wAgents)
            ))
    }
}
