function Remove-K3sCluster {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [switch]$PurgeFiles,
        [switch]$PurgeMultipass,
        [switch]$SkipConfirm,
        [switch]$Force
    )

    $multipass = Get-MultipassCmd

    $state = Get-State
    $listObj = $null
    $existing = $null
    try {
        $listObj = Get-MultipassListJson -MultipassCmd $multipass
    }
    catch {
        $listObj = $null
    }
    if ($listObj -and $null -ne $listObj.list) {
        $existing = @($listObj.list | ForEach-Object { $_.name })
    }

    $vms = @()
    $e = $null

    if ($state.clusters -and ($state.clusters -is [hashtable]) -and $state.clusters.ContainsKey($ClusterName)) {
        $e = $state.clusters[$ClusterName]
        if ($e -and (Test-HasProperty -Object $e -Name "servers") -and $e.servers) {
            $vms += ConvertTo-Array $e.servers
        }
        if ($e -and (Test-HasProperty -Object $e -Name "agents") -and $e.agents) {
            $vms += ConvertTo-Array $e.agents
        }
        $vms = Get-UniqueList -Items $vms
    }

    $vms = @($vms)
    if (@($vms).Count -eq 0) {
        $inv = Get-ClusterInventory -MultipassCmd $multipass
        if ($inv.Clusters.ContainsKey($ClusterName)) {
            $vms = Get-UniqueList -Items @($inv.Clusters[$ClusterName].Servers + $inv.Clusters[$ClusterName].Agents)
        }
    }

    if ($null -ne $existing) {
        $vms = @((ConvertTo-Array ($vms | Where-Object { $existing -contains $_ })))
    }
    else {
        $vms = @((ConvertTo-Array $vms))
    }
    $foundVms = (@($vms).Count -gt 0)
    $vmDesc = if (@($vms).Count -gt 0) { ($vms -join ', ') } else { '(none)' }
    $target = ("{0} (VMs: {1})" -f $ClusterName, $vmDesc)
    if (-not $PSCmdlet.ShouldProcess($target, 'Delete k3s cluster')) {
        return
    }

    Write-Host "Deleting cluster: $ClusterName" -ForegroundColor Yellow

    if (-not $foundVms) {
        Write-Host "No VMs found for cluster '$ClusterName'." -ForegroundColor Yellow
    }
    else {
        Write-Host "Found VMs: $($vms -join ', ')" -ForegroundColor Cyan
        if (-not $SkipConfirm -and -not $Force) {
            if (-not (Read-YesNo -Prompt "Stop and delete these VMs?" -Default $false)) {
                Write-Host "Operation cancelled." -ForegroundColor Green; return
            }
        }
    }

    if (-not $SkipConfirm -and -not $Force -and -not $PurgeFiles) {
        $PurgeFiles = Read-YesNo -Prompt "Purge local files for cluster '$ClusterName'?" -Default $false
    }

    if ($foundVms) {
        if (-not $PurgeMultipass -and -not $SkipConfirm -and -not $Force) {
            if (Read-YesNo -Prompt "Purge deleted instances from Multipass cache?" -Default $false) {
                $PurgeMultipass = $true
            }
        }
        Write-Host ("Stopping VMs: {0}" -f ($vms -join ", ")) -ForegroundColor DarkGray
        Invoke-Multipass -MultipassCmd $multipass -MpArgs (@("stop") + $vms) -AllowNonZero | Out-Null

        if ($PurgeMultipass) {
            Write-Host ("Deleting VMs: {0}" -f ($vms -join ", ")) -ForegroundColor DarkGray
            try {
                Invoke-Multipass -MultipassCmd $multipass -MpArgs (@("delete", "--purge") + $vms) | Out-Null
            }
            catch {
                Write-Warning ("Batch delete --purge failed; falling back to per-VM delete. {0}" -f $_.Exception.Message)
                foreach ($vm in $vms) {
                    Write-Host "  Deleting: $vm" -ForegroundColor DarkGray
                    Invoke-Multipass -MultipassCmd $multipass -MpArgs @("delete", "--purge", $vm) -AllowNonZero | Out-Null
                }
            }
        }
        else {
            Write-Host ("Deleting VMs: {0}" -f ($vms -join ", ")) -ForegroundColor DarkGray
            try {
                Invoke-Multipass -MultipassCmd $multipass -MpArgs (@("delete") + $vms) | Out-Null
            }
            catch {
                Write-Warning ("Batch delete failed; falling back to per-VM delete. {0}" -f $_.Exception.Message)
                foreach ($vm in $vms) {
                    Write-Host "  Deleting: $vm" -ForegroundColor DarkGray
                    Invoke-Multipass -MultipassCmd $multipass -MpArgs @("delete", $vm) -AllowNonZero | Out-Null
                }
            }
        }
    }
    if ($foundVms) {
        try {
            $listObjAfter = Get-MultipassListJson -MultipassCmd $multipass
            $present = @{}
            foreach ($vm in @($listObjAfter.list)) {
                $present[$vm.name] = $vm.state
            }

            $still = @()
            foreach ($n in @($vms)) {
                if ($present.ContainsKey($n) -and $present[$n] -ne 'Deleted') {
                    $still += $n
                }
            }

            if ($still.Count -gt 0) {
                Remove-ClusterInstancesBestEffort -MultipassCmd $multipass -ClusterName $ClusterName -InstanceNames @($still) -WaitForAppearSeconds 15 -RetryIntervalSeconds 1
            }
        }
        catch {
            Remove-ClusterInstancesBestEffort -MultipassCmd $multipass -ClusterName $ClusterName -InstanceNames @($vms) -WaitForAppearSeconds 15 -RetryIntervalSeconds 1
        }
    }

    $mergedPath = $null
    if ($e -and (Test-HasProperty -Object $e -Name "merged") -and $e.merged) {
        $mergedPath = Expand-UserPath $e.merged
        if ($mergedPath -and (Test-Path -LiteralPath $mergedPath)) {
            Switch-CurrentContextIfMatches -KubeconfigPath $mergedPath -BadContext $ClusterName
            Remove-KubeconfigEntries -KubeconfigPath $mergedPath -ClusterName $ClusterName
            Set-KubeconfigCurrentContextPreferred -KubeconfigPath $mergedPath -PreferredContext ""
            Update-KubeconfigIfEmpty -KubeconfigPath $mergedPath
        }
    }
    $defaultMerged = Join-Path (Get-Location).Path "kubeconfig-merged.yaml"
    if ($defaultMerged -and (Test-Path -LiteralPath $defaultMerged)) {
        Switch-CurrentContextIfMatches -KubeconfigPath $defaultMerged -BadContext $ClusterName
        Remove-KubeconfigEntries -KubeconfigPath $defaultMerged -ClusterName $ClusterName
        Set-KubeconfigCurrentContextPreferred -KubeconfigPath $defaultMerged -PreferredContext ""
        Update-KubeconfigIfEmpty -KubeconfigPath $defaultMerged
    }

    $kc = $null
    try {
        $kc = Get-UserKubeconfigFilePath
        Switch-CurrentContextIfMatches -KubeconfigPath $kc -BadContext $ClusterName
        Remove-KubeconfigEntries -KubeconfigPath $kc -ClusterName $ClusterName
        Set-KubeconfigCurrentContextPreferred -KubeconfigPath $kc -PreferredContext ""
        Update-KubeconfigIfEmpty -KubeconfigPath $kc
    }
    catch {
        Write-Verbose ("kubeconfig cleanup failed (suppressed): {0}" -f $_.Exception.Message)
    }

    if ($PurgeFiles) {
        try {
            $cleanupDirRaw = if ($e -and (Test-HasProperty -Object $e -Name "outputDir") -and $e.outputDir) {
                $e.outputDir
            }
            else {
                (Get-ClustersRoot)
            }
            $cleanupDir = Resolve-ExistingDirectoryPath -PathLike $cleanupDirRaw
            if ([string]::IsNullOrWhiteSpace($cleanupDir)) {
                $cleanupDir = (Get-Location).Path
            }
            $searchDirs = @($cleanupDir)
            $clusterSubdir = Join-Path $cleanupDir $ClusterName
            if ((Split-Path -Leaf $cleanupDir) -ine $ClusterName -and (Test-Path -LiteralPath $clusterSubdir)) {
                $searchDirs += $clusterSubdir
            }
            $searchDirs = Get-UniqueListPreserveOrder -Items $searchDirs

            $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
            $cmp = if ($isWin) {
                [StringComparer]::OrdinalIgnoreCase
            }
            else {
                [StringComparer]::Ordinal
            }
            $candidates = New-Object "System.Collections.Generic.HashSet[string]"($cmp)

            try {

                $markerDirs = @()
                if ((Split-Path -Leaf $cleanupDir) -ieq $ClusterName) { $markerDirs += $cleanupDir }
                if ($clusterSubdir -and (Test-Path -LiteralPath $clusterSubdir)) { $markerDirs += $clusterSubdir }
                $markerDirs = Get-UniqueListPreserveOrder -Items $markerDirs

                foreach ($md in @($markerDirs)) {
                    if ([string]::IsNullOrWhiteSpace($md)) { continue }
                    $marker = Get-ClusterArtifactsMarkerPath -ClusterDir $md
                    if ($marker -and (Test-Path -LiteralPath $marker)) { [void]$candidates.Add($marker) }
                }
            }
            catch {
                Write-NonFatalError $_
            }

            $clusterEsc = [regex]::Escape($ClusterName)
            $namePatterns = @(
                "^${clusterEsc}-kubeconfig\\.ya?ml$",
                "^${clusterEsc}-kubeconfig-orig\\.ya?ml$",
                "^${clusterEsc}-srv\\d+-cloud-init\\.ya?ml$",
                "^${clusterEsc}-agt\\d+-cloud-init\\.ya?ml$"
            )
            $nameRegex = [regex]::new(($namePatterns -join '|'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

            foreach ($dir in @($searchDirs)) {
                if (-not (Test-Path -LiteralPath $dir)) {
                    continue
                }
                foreach ($f in Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue) {
                    if ($nameRegex.IsMatch($f.Name)) {
                        [void]$candidates.Add($f.FullName)
                    }
                }
                foreach ($f in Get-ChildItem -LiteralPath $dir -File -Filter "$ClusterName-*-cloud-init.y*ml" -ErrorAction SilentlyContinue) {
                    [void]$candidates.Add($f.FullName)
                }
            }

            $rxAgt = '^k3s-agt(\d+)-' + [regex]::Escape($ClusterName) + '$'
            $rxSrv = '^k3s-srv(\d+)-' + [regex]::Escape($ClusterName) + '$'
            foreach ($vm in @($vms)) {
                if ($vm -match $rxAgt) {
                    $idx = $matches[1]
                    foreach ($ext in @("yaml", "yml")) {
                        $p = Join-Path $cleanupDir ("{0}-agt{1}-cloud-init.{2}" -f $ClusterName, $idx, $ext)
                        if (Test-Path -LiteralPath $p) {
                            [void]$candidates.Add($p)
                        }
                    }
                    continue
                }
                if ($vm -match $rxSrv) {
                    $idx = $matches[1]
                    foreach ($ext in @("yaml", "yml")) {
                        $p = Join-Path $cleanupDir ("{0}-srv{1}-cloud-init.{2}" -f $ClusterName, $idx, $ext)
                        if (Test-Path -LiteralPath $p) {
                            [void]$candidates.Add($p)
                        }
                    }
                }
            }

            if ($e) {
                if ((Test-HasProperty -Object $e -Name "kubeconfig") -and $e.kubeconfig) {
                    [void]$candidates.Add((Expand-UserPath $e.kubeconfig))
                }
                if ((Test-HasProperty -Object $e -Name "kubeconfigOrig") -and $e.kubeconfigOrig) {
                    [void]$candidates.Add((Expand-UserPath $e.kubeconfigOrig))
                }

                if ((Test-HasProperty -Object $e -Name "merged") -and $e.merged -and (Test-Path -LiteralPath (Expand-UserPath $e.merged))) {
                    if (Test-IsClusterScopedMergedKubeconfig -MergedPath $e.merged -ClusterName $ClusterName -CleanupDir $cleanupDir) {
                        [void]$candidates.Add((Expand-UserPath $e.merged))
                    }
                    else {
                        Write-Warning "Not deleting merged kubeconfig: $($e.merged)"
                    }
                }
            }

            $failedDeletes = New-Object System.Collections.Generic.List[object]
            foreach ($p in $candidates) {
                if (-not $p) { continue }
                if (-not (Test-Path -LiteralPath $p)) { continue }

                $lastErr = $null
                $deleted = $false
                for ($i = 0; $i -lt 3; $i++) {
                    try {
                        try {
                            $it = Get-Item -LiteralPath $p -Force -ErrorAction Stop
                            if ($it -and ($it.Attributes -band [System.IO.FileAttributes]::ReadOnly)) {
                                $it.Attributes = ($it.Attributes -bxor [System.IO.FileAttributes]::ReadOnly)
                            }
                        }
                        catch { }

                        Remove-Item -LiteralPath $p -Force -ErrorAction Stop
                        if (-not (Test-Path -LiteralPath $p)) {
                            $deleted = $true
                            break
                        }
                    }
                    catch {
                        $lastErr = $_
                        Start-Sleep -Milliseconds 200
                    }
                }

                if (-not $deleted) {
                    $msg = if ($lastErr) { $lastErr.Exception.Message } else { "Unknown error." }
                    [void]$failedDeletes.Add([pscustomobject]@{ Path = $p; Error = $msg })
                }
            }

            if ($failedDeletes.Count -gt 0) {
                Write-Warning "Failed to delete one or more local artifacts (some may be locked or have restrictive ACLs):"
                foreach ($fd in $failedDeletes) {
                    Write-Warning ("  {0} :: {1}" -f $fd.Path, $fd.Error)
                }
            }

            $removeDirs = New-Object System.Collections.Generic.List[string]
            if ($e -and (Test-HasProperty -Object $e -Name "outputDirCreated") -and $e.outputDirCreated) {
                [void]$removeDirs.Add($cleanupDir)
            }
            if ((Split-Path -Leaf $cleanupDir) -ieq $ClusterName) {
                [void]$removeDirs.Add($cleanupDir)
            }
            if ((Split-Path -Leaf $clusterSubdir) -ieq $ClusterName) {
                [void]$removeDirs.Add($clusterSubdir)
            }

            $cwd = (Get-Location).Path
            foreach ($dir in @($removeDirs | Select-Object -Unique)) {
                if ([string]::IsNullOrWhiteSpace($dir)) {
                    continue
                }
                if ($dir -eq $cwd) {
                    continue
                }
                try {
                    if (Test-Path -LiteralPath $dir) {
                        $items = Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                        if (-not $items -or @($items).Count -eq 0) {
                            Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                catch {
                    Write-NonFatalError $_
                }
            }
        }
        catch {
            Write-Verbose ("Local file purge failed (suppressed): {0}" -f $_.Exception.Message)
        }
    }

    Remove-ClusterState $ClusterName

    $allowedAfter = @()
    try {
        $allowedAfter = Get-ActiveClusterNames -MultipassCmd $multipass
    }
    catch {
        $allowedAfter = @()
    }

    $allowEmpty = $false
    try {
        if (@($allowedAfter).Count -eq 0) {
            if (Restore-UserKubeconfigBaseline -ClearBaseline) {
            }
        }
        else {
            try {
                if ($kc -and (Test-Path -LiteralPath $kc)) {
                    Remove-KubeconfigStaleClusters -KubeconfigPath $kc -AllowedClusters $allowedAfter -AllowEmpty:$allowEmpty
                }
                if ($mergedPath -and (Test-Path -LiteralPath $mergedPath)) {
                    Remove-KubeconfigStaleClusters -KubeconfigPath $mergedPath -AllowedClusters $allowedAfter -AllowEmpty:$allowEmpty
                }
                if ($defaultMerged -and (Test-Path -LiteralPath $defaultMerged)) {
                    Remove-KubeconfigStaleClusters -KubeconfigPath $defaultMerged -AllowedClusters $allowedAfter -AllowEmpty:$allowEmpty
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }
    }
    catch {
        Write-Verbose ("Final kubeconfig housekeeping failed (suppressed): {0}" -f $_.Exception.Message)
    }
    Write-Host ""
    Write-Host "Cluster '$ClusterName' deleted." -ForegroundColor Green
}
