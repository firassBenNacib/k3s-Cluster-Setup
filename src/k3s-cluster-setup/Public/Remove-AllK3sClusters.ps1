function Remove-AllK3sClusters {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    param([switch]$PurgeFiles, [switch]$PurgeMultipass, [switch]$Force)

    $multipass = Get-MultipassCmd
    if (-not $PSCmdlet.ShouldProcess('ALL k3s clusters', 'Delete all clusters')) { return }
    $confirmSpecified = $PSBoundParameters.ContainsKey("Confirm")
    if (-not $Force -and -not $confirmSpecified) {
        if (-not (Read-YesNo -Prompt "Are you sure you want to delete ALL clusters?" -Default $false)) {
            Write-Host "Operation cancelled." -ForegroundColor Green
            return
        }
    }
    if (-not $PurgeMultipass -and -not $Force) {
        if (Read-YesNo -Prompt "Purge deleted instances from Multipass cache after deletion?" -Default $false) {
            $PurgeMultipass = $true
        }
    }
    if (-not $Force -and -not $PurgeFiles) {
        $PurgeFiles = Read-YesNo -Prompt "Purge local files for all clusters after deletion?" -Default $false
    }

    $state = Get-State
    $purgeRoots = New-Object "System.Collections.Generic.HashSet[string]"([StringComparer]::OrdinalIgnoreCase)
    if ($state -and $state.clusters) {
        $entries = @()
        if ($state.clusters -is [hashtable]) {
            $entries = @($state.clusters.Values)
        }
        else {
            $entries = @($state.clusters.PSObject.Properties | ForEach-Object { $_.Value })
        }
        foreach ($e in @($entries)) {
            if ($e -and (Test-HasProperty -Object $e -Name "outputDir") -and $e.outputDir) {
                $dir = Resolve-ExistingDirectoryPath -PathLike $e.outputDir
                if (-not [string]::IsNullOrWhiteSpace($dir)) {
                    [void]$purgeRoots.Add($dir)
                }
            }
        }
    }

    try {
        $clustersRoot = Get-ClustersRoot
        if (-not [string]::IsNullOrWhiteSpace($clustersRoot)) {
            [void]$purgeRoots.Add($clustersRoot)
        }
    }
    catch {
        Write-NonFatalError $_
    }

    $inv = Get-ClusterInventory -MultipassCmd $multipass
    $deleted = 0
    $failed = 0

    foreach ($c in @($inv.Names)) {
        try {

            Remove-K3sCluster -ClusterName $c -PurgeFiles:$PurgeFiles -PurgeMultipass:$PurgeMultipass -SkipConfirm -Force:$Force -Confirm:$false
            $deleted++
        }
        catch {
            $failed++
            Write-Warning "Failed deleting '$c': $($_.Exception.Message)"
        }
    }
    if ($PurgeMultipass) {
        Invoke-Multipass -MultipassCmd $multipass -MpArgs @("purge") -AllowNonZero | Out-Null
    }

    $allowedAfter = @()
    try {
        $allowedAfter = Get-ActiveClusterNames -MultipassCmd $multipass
    }
    catch {
        $allowedAfter = @()
    }

    $allowEmpty = $false
    if ($PurgeFiles) {
        $totalRemoved = 0
        foreach ($root in @($purgeRoots)) {
            if ([string]::IsNullOrWhiteSpace($root)) {
                continue
            }
            $totalRemoved += Remove-StrayClusterArtifacts -RootDir $root -AllowedClusters $allowedAfter
        }
        if ($totalRemoved -gt 0) {
            Write-Host "Removed $totalRemoved local artifact file(s)." -ForegroundColor Yellow
        }
    }
    if ($PurgeFiles -and @($allowedAfter).Count -eq 0) {
        try {
            Use-StateFileLock -ScriptBlock {
                $st = Get-StateUnlocked
                if ($st.clusters) {
                    if ($st.clusters -is [hashtable]) {
                        $st.clusters.Clear()
                    }
                    else {
                        foreach ($p in @($st.clusters.PSObject.Properties)) {
                            [void]$st.clusters.PSObject.Properties.Remove($p.Name)
                        }
                    }
                }
                Set-StateUnlocked $st
            }
        }
        catch {
            Write-Verbose ("Failed to clear state clusters (suppressed): {0}" -f $_.Exception.Message)
        }
    }
    try {
        $kc = Get-UserKubeconfigFilePath

        if (@($allowedAfter).Count -eq 0) {
            if (Restore-UserKubeconfigBaseline -ClearBaseline) {
                Write-Host "Restored user kubeconfig baseline." -ForegroundColor Yellow
            }
        }
        else {
            if ($kc -and (Test-Path -LiteralPath $kc)) {
                Remove-KubeconfigStaleClusters -KubeconfigPath $kc -AllowedClusters $allowedAfter -AllowEmpty:$allowEmpty
            }
            $mergedDefault = Join-Path (Get-Location).Path "kubeconfig-merged.yaml"
            if (Test-Path -LiteralPath $mergedDefault) {
                Remove-KubeconfigStaleClusters -KubeconfigPath $mergedDefault -AllowedClusters $allowedAfter -AllowEmpty:$allowEmpty
            }
        }
    }
    catch {

        Write-Verbose ("kubeconfig cleanup failed (suppressed): {0}" -f $_.Exception.Message)
    }

    if ($PurgeFiles -and @($allowedAfter).Count -eq 0) {
        try {
            Use-StateFileLock -ScriptBlock {
                $st = Get-StateUnlocked
                $clustersEmpty = $true
                if ($st.clusters) {
                    if ($st.clusters -is [hashtable]) {
                        $clustersEmpty = ($st.clusters.Count -eq 0)
                    }
                    else {
                        $clustersEmpty = ($st.clusters.PSObject.Properties.Count -eq 0)
                    }
                }
                $metaEmpty = $true
                if ($st.meta) {
                    foreach ($p in $st.meta.PSObject.Properties) {
                        if ($null -ne $p.Value -and -not [string]::IsNullOrWhiteSpace([string]$p.Value)) {
                            $metaEmpty = $false
                            break
                        }
                    }
                }
                if ($clustersEmpty -and $metaEmpty) {
                    if (Test-Path -LiteralPath $script:StatePath) {
                        Remove-Item -LiteralPath $script:StatePath -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        catch {
            Write-Verbose ("Failed to remove empty state file (suppressed): {0}" -f $_.Exception.Message)
        }
    }

    Write-Host ""
    Write-Host ("DeleteAll finished. Deleted: {0} / {1}. Failed: {2}" -f $deleted, @($inv.Names).Count, $failed) -ForegroundColor Green
}
