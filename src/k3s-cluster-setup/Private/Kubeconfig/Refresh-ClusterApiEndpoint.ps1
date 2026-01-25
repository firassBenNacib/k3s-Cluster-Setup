function Refresh-ClusterApiEndpoint {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Internal helper.')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClusterName,

        [Parameter(Mandatory = $false)]
        [string]$MultipassCmd = "",

        [Parameter(Mandatory = $false)]
        [int]$MaxAttempts = 60,

        [Parameter(Mandatory = $false)]
        [int]$DelaySeconds = 2
    )

    $mp = if ([string]::IsNullOrWhiteSpace($MultipassCmd)) { Get-MultipassCmd } else { $MultipassCmd }

    $clusterDir = Get-ClusterArtifactsDir -ClusterName $ClusterName
    $clusterKubeconfigPath = Join-Path $clusterDir ("{0}-kubeconfig.yaml" -f $ClusterName)
    $origKubeconfigPath = Join-Path $clusterDir ("{0}-kubeconfig-orig.yaml" -f $ClusterName)

    $inventory = Get-ClusterInventory -MultipassCmd $mp
    $clusterEntry = $null
    $clustersIsDictionary = $false
    if ($inventory -and $inventory.Clusters) {
        $clustersIsDictionary = $inventory.Clusters -is [System.Collections.IDictionary]
        if ($clustersIsDictionary) {
            if ($inventory.Clusters.Contains($ClusterName)) {
                $clusterEntry = $inventory.Clusters[$ClusterName]
            }
        }
        else {
            $clusterEntry = $inventory.Clusters | Where-Object { $_.Name -eq $ClusterName } | Select-Object -First 1
        }
    }
    if (-not $clusterEntry) {
        throw "Cluster '$ClusterName' not found. Ensure VMs exist and the cluster folder exists under '.\\clusters\\'."
    }

    $servers = @()
    $agents = @()
    $primaryFromInventory = $null
    if ($clustersIsDictionary) {
        $servers = @($clusterEntry.Servers)
        $agents = @($clusterEntry.Agents)
    } else {
        $servers = @($clusterEntry.Servers)
        $agents = @($clusterEntry.Agents)
        if (Test-HasProperty -Object $clusterEntry -Name "Primary") {
            $primaryFromInventory = $clusterEntry.Primary
        }
    }

    $preferredPrimary = "k3s-srv1-$ClusterName"
    $primary = if (-not [string]::IsNullOrWhiteSpace($primaryFromInventory)) {
        $primaryFromInventory
    } elseif ($servers -contains $preferredPrimary) {
        $preferredPrimary
    } else {
        $servers | Select-Object -First 1
    }

    if ([string]::IsNullOrWhiteSpace($primary)) {
        throw "Cluster '$ClusterName' has no server nodes."
    }

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

    $currentIp = Get-KubeconfigServerIp -Path $clusterKubeconfigPath

    $endpointUpdated = $false
    $agentsUpdated = $true
    if ($agents -and @($agents).Count -gt 0) {
      $agentsUpdated = $false
    }

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Stop-IfCancelled

    $newIp = Get-InstanceIPv4 -MultipassCmd $mp -InstanceName $primary
    if (-not $newIp) {
      Write-Verbose "[$attempt/$MaxAttempts] Could not determine a host-reachable IPv4 for '$primary' yet. Retrying..."
      Start-Sleep -Seconds $DelaySeconds
      continue
    }

    if (($null -eq $currentIp) -or ($currentIp -ne $newIp)) {
      Write-Verbose "Detected API endpoint IP change for cluster '$ClusterName': '$currentIp' -> '$newIp'. Updating kubeconfigs/state now."

      if ($clusterKubeconfigPath -and (Test-Path $clusterKubeconfigPath)) {
        Update-KubeconfigServerAddressInFile -Path $clusterKubeconfigPath -ServerHost $newIp | Out-Null
      }
      if ($origKubeconfigPath -and (Test-Path $origKubeconfigPath)) {
        Update-KubeconfigServerAddressInFile -Path $origKubeconfigPath -ServerHost $newIp | Out-Null
      }

      try {
        if ($clusterKubeconfigPath -and (Test-Path $clusterKubeconfigPath)) {
          Update-UserKubeconfigFromMerged -MergedPath $clusterKubeconfigPath -PreferredContext $ClusterName | Out-Null
        }
      } catch {
        Write-Verbose "User kubeconfig update skipped: $($_.Exception.Message)"
      }

      try {
        if ($agents -and @($agents).Count -gt 0) {
          $agentsUpdated = [bool](Update-K3sAgentsServerUrl -MultipassCmd $mp -AgentInstances $agents -ServerIp $newIp -TimeoutSeconds 180)
        }
      } catch {
        Write-Verbose "Agent server URL update skipped: $($_.Exception.Message)"
      }

      try {
        $state = Get-State
        if ($state.clusters.ContainsKey($ClusterName)) {
          $entry = $state.clusters[$ClusterName]
          $entry.serverIp = $newIp
          $entry.primary = $primary
          $entry.servers = $servers
          $entry.agents  = $agents
          Set-ClusterState -Name $ClusterName -Entry $entry
        }
      } catch {
        Write-Verbose "State update skipped: $($_.Exception.Message)"
      }

      $currentIp = $newIp
      $endpointUpdated = $true
    } else {
      try {
        if ($clusterKubeconfigPath -and (Test-Path $clusterKubeconfigPath)) {
          Update-UserKubeconfigFromMerged -MergedPath $clusterKubeconfigPath -PreferredContext $ClusterName | Out-Null
        }
      } catch {
        Write-Verbose "User kubeconfig update skipped: $($_.Exception.Message)"
      }

      if (-not $agentsUpdated -and $agents -and @($agents).Count -gt 0 -and ($attempt % 5 -eq 0)) {
        try {
          $agentsUpdated = [bool](Update-K3sAgentsServerUrl -MultipassCmd $mp -AgentInstances $agents -ServerIp $newIp -TimeoutSeconds 180)
        } catch {
          Write-Verbose "Agent server URL update retry skipped: $($_.Exception.Message)"
        }
      }
    }

    $hostReachable = Test-TcpPortOpen -TargetHost $newIp -Port 6443 -TimeoutMs 1500
    $k3sReady = $false
    if ($hostReachable) {
      $k3sReady = Test-K3sReady -MultipassCmd $mp -Primary $primary
    }

    if ($k3sReady -and $hostReachable) {
      return [pscustomobject]@{
        Updated  = $endpointUpdated
        Ready    = $true
        ServerIp = $newIp
        Cluster  = $ClusterName
      }
    }

    Write-Verbose "[$attempt/$MaxAttempts] API not ready yet (hostReachable=$hostReachable, k3sReady=$k3sReady). Retrying..."
    Start-Sleep -Seconds $DelaySeconds
  }

  if ($endpointUpdated -and $currentIp) {
    Write-Warning "Cluster '$ClusterName' endpoint was updated to '$currentIp', but the Kubernetes API (tcp/6443) did not become reachable within the allotted time."
    return [pscustomobject]@{
      Updated  = $true
      Ready    = $false
      ServerIp = $currentIp
      Cluster  = $ClusterName
    }
  }

  throw "Timed out waiting for k3s API endpoint to become ready for cluster '$ClusterName'."
}
