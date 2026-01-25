function Remove-K3sNode {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [AllowEmptyString()][string]$NodeName,
        [switch]$Force,
        [switch]$PurgeFiles,
        [switch]$PurgeMultipass
    )

    $multipass = Get-MultipassCmd
    $ClusterName = ConvertTo-ClusterName -Name $ClusterName

    $inv = Get-ClusterInventory -MultipassCmd $multipass
    $names = @((ConvertTo-Array $inv.Names))
    if ($names.Count -eq 0) {
        Write-Host "No clusters found." -ForegroundColor Yellow
        return
    }
    if (-not $inv.Clusters.ContainsKey($ClusterName)) {
        Write-Host "Cluster '$ClusterName' not found." -ForegroundColor Yellow
        return
    }

    $entry = $inv.Clusters[$ClusterName]
    $nodes = @((ConvertTo-Array (Get-UniqueList -Items ($entry.Servers + $entry.Agents))))
    if ($nodes.Count -eq 0) {
        Write-Host "No nodes found." -ForegroundColor Yellow
        return
    }

    if ([string]::IsNullOrWhiteSpace($NodeName)) {
        $NodeName = Select-NodePrompt -cluster $ClusterName -MultipassCmd $multipass
        if ([string]::IsNullOrWhiteSpace($NodeName)) {
            return
        }
    }
    elseif ($nodes -notcontains $NodeName) {
        Write-Host "Node '$NodeName' not found." -ForegroundColor Yellow
        return
    }

    if (-not $PSCmdlet.ShouldProcess("$ClusterName/$NodeName", 'Delete cluster node')) {
        return
    }

    Write-Host "Deleting node '$NodeName' from cluster: $ClusterName" -ForegroundColor Yellow

    if (-not $Force) {
        if (-not (Read-YesNo -Prompt "Delete VM '$NodeName'?" -Default $false)) {
            Write-Host "Operation cancelled." -ForegroundColor Green; return
        }
    }
    if (-not $PurgeMultipass -and -not $Force) {
        if (Read-YesNo -Prompt "Purge deleted instances from Multipass cache?" -Default $false) {
            $PurgeMultipass = $true
        }
    }

    if (-not $PurgeFiles -and -not $Force) {
        if (Read-YesNo -Prompt "Purge local files for node '$NodeName' after deletion?" -Default $false) {
            $PurgeFiles = $true
        }
    }

    $kubectlKubeconfig = $null
    $kubectlContextArgs = @()
    try {
        $state = Get-State
        if ($state.clusters -and ($state.clusters -is [hashtable]) -and $state.clusters.ContainsKey($ClusterName)) {
            $e = $state.clusters[$ClusterName]
            if ($e -and (Test-HasProperty -Object $e -Name "kubeconfig") -and $e.kubeconfig) {
                $kubectlKubeconfig = Expand-UserPath $e.kubeconfig
                $kubectlContextArgs = @()
            }
            elseif ($e -and (Test-HasProperty -Object $e -Name "merged") -and $e.merged) {
                $kubectlKubeconfig = Expand-UserPath $e.merged
                $kubectlContextArgs = @("--context", $ClusterName)
            }
        }
        if ([string]::IsNullOrWhiteSpace($kubectlKubeconfig)) {
            try {
                $kubectlKubeconfig = Get-UserKubeconfigFilePath
                $kubectlContextArgs = @("--context", $ClusterName)
            }
            catch {
                $kubectlKubeconfig = $null
            }
        }
    }
    catch {
        $kubectlKubeconfig = $null
    }

    $canKubectl = $false
    if (-not [string]::IsNullOrWhiteSpace($kubectlKubeconfig) -and (Test-Path -LiteralPath $kubectlKubeconfig) -and (Test-HasKubectl)) {

        $nodeExists = $false
        try {
            $out = Invoke-KubectlConfigReadSafe -KubeconfigPath $kubectlKubeconfig -KubectlArgs (@($kubectlContextArgs + @("get", "node", $NodeName, "-o", "name")))
            if ($out -and ($out -match [regex]::Escape($NodeName))) {
                $nodeExists = $true
                $canKubectl = $true
            }
        }
        catch {
            $nodeExists = $false
        }

        if ($nodeExists) {
            try {

                [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $kubectlKubeconfig -KubectlArgs (@($kubectlContextArgs + @(
                                "drain", $NodeName,
                                "--ignore-daemonsets",
                                "--delete-emptydir-data",
                                "--force",
                                "--grace-period=30",
                                "--timeout=2m"
                            ))))
            }
            catch {
                Write-NonFatalError $_
            }
        }
    }

    Invoke-Multipass -MultipassCmd $multipass -MpArgs @("stop", $NodeName) -AllowNonZero | Out-Null
    Invoke-Multipass -MultipassCmd $multipass -MpArgs @("delete", $NodeName) -AllowNonZero | Out-Null
    if ($PurgeMultipass) {
        Invoke-Multipass -MultipassCmd $multipass -MpArgs @("purge") -AllowNonZero | Out-Null
    }

    if ($canKubectl) {
        try {

            [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $kubectlKubeconfig -KubectlArgs (@($kubectlContextArgs + @(
                            "delete", "node", $NodeName,
                            "--wait=false"
                        ))))
        }
        catch {
            Write-Warning "Kubernetes node cleanup failed. You can run: kubectl --kubeconfig '$kubectlKubeconfig' $($kubectlContextArgs -join ' ') delete node '$NodeName'"
        }
    }

    Update-ClusterStateAfterNodeDelete -ClusterName $ClusterName -NodeName $NodeName -MultipassCmd $multipass

    if ($PurgeFiles) {
        try {
            $clusterDir = Get-ClusterArtifactsDirFromStateOrDefault -ClusterName $ClusterName

            $deleted = @(Remove-NodeLocalArtifacts -ClusterName $ClusterName -NodeName $NodeName -ClusterDir $clusterDir)
            if ($deleted.Count -gt 0) {
                Write-Host "Purged local node files:" -ForegroundColor Yellow
                foreach ($p in $deleted) { Write-Host "  - $p" }
            }
        }
        catch {
            Write-Warning "Failed to purge local files for node '$NodeName': $($_.Exception.Message)"
        }
    }

    Write-Host ""
    Write-Host "Node '$NodeName' deleted." -ForegroundColor Green
}
