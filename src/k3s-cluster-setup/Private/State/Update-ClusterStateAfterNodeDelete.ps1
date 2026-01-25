function Update-ClusterStateAfterNodeDelete {
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$NodeName,
        [string]$MultipassCmd = ""
    )

    Use-StateFileLock -ScriptBlock {
        $state = Get-StateUnlocked
        if (-not ($state.clusters -and ($state.clusters -is [hashtable]) -and $state.clusters.ContainsKey($ClusterName))) {
            return
        }

        $e = $state.clusters[$ClusterName]
        $changed = $false
        $primaryChanged = $false

        if ($e -and (Test-HasProperty -Object $e -Name "servers") -and $e.servers) {
            $newServers = @($e.servers | Where-Object { $_ -ne $NodeName })
            if (@($newServers).Count -ne @($e.servers).Count) {
                $e.servers = $newServers
                $changed = $true
            }
        }
        if ($e -and (Test-HasProperty -Object $e -Name "agents") -and $e.agents) {
            $newAgents = @($e.agents | Where-Object { $_ -ne $NodeName })
            if (@($newAgents).Count -ne @($e.agents).Count) {
                $e.agents = $newAgents
                $changed = $true
            }
        }

        if ($e -and (Test-HasProperty -Object $e -Name "primary") -and $e.primary -and ($e.primary -eq $NodeName)) {
            $e.primary = if ($e -and (Test-HasProperty -Object $e -Name "servers") -and @($e.servers).Count -gt 0) {
                @($e.servers)[0]
            }
            else {
                ""
            }
            $changed = $true
            $primaryChanged = $true
        }

        $serverCount = if ($e -and (Test-HasProperty -Object $e -Name "servers")) { @($e.servers).Count } else { 0 }
        $agentCount = if ($e -and (Test-HasProperty -Object $e -Name "agents")) { @($e.agents).Count } else { 0 }

        if (($serverCount -eq 0) -and ($agentCount -eq 0)) {
            [void]$state.clusters.Remove($ClusterName)
            Set-StateUnlocked $state
            return
        }

        if ($primaryChanged) {
            if ($e -is [System.Collections.IDictionary]) {
                $e["serverIp"] = ""
            }
            elseif (-not (Test-HasProperty -Object $e -Name "serverIp")) {
                $e | Add-Member -NotePropertyName serverIp -NotePropertyValue "" -Force
            }
            else {
                $e.serverIp = ""
            }

            $primaryName = if ($e -and (Test-HasProperty -Object $e -Name "primary")) { $e.primary } else { "" }
            if (-not [string]::IsNullOrWhiteSpace($primaryName) -and -not [string]::IsNullOrWhiteSpace($MultipassCmd)) {
                try {
                    $e.serverIp = Get-InstanceIPv4 -MultipassCmd $MultipassCmd -InstanceName $primaryName
                }
                catch {
                    Write-Verbose ("Failed to refresh primary server IP after node delete: {0}" -f $_.Exception.Message)
                    $e.serverIp = ""
                }
            }
            $changed = $true
        }

        if ($changed) {
            $state.clusters[$ClusterName] = $e
            Set-StateUnlocked $state
        }
    }
}
