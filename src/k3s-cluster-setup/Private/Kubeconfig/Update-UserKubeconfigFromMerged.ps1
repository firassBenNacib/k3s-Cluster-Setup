function Update-UserKubeconfigFromMerged {
    param([Parameter(Mandatory)][string]$MergedPath, [string]$PreferredContext = "")

    if (-not (Test-Path -LiteralPath $MergedPath)) {
        throw "Merged kubeconfig not found: $MergedPath"
    }

    $userCfg = Get-UserKubeconfigFilePath
    $userKubeDir = Split-Path -Parent $userCfg
    New-SafeDirectory -Path $userKubeDir

    [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($MergedPath, $userCfg) -WaitSeconds 5)

    if (Test-Path -LiteralPath $userCfg) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $bak = "$userCfg.bak-$stamp"
        Copy-Item -LiteralPath $userCfg -Destination $bak -Force -ErrorAction SilentlyContinue

        try {
            Use-StateFileLock -ScriptBlock {
                $state = Get-StateUnlocked
                $meta = $state.meta
                if (-not (Test-HasProperty -Object $state -Name "meta") -or -not $meta) {
                    $meta = [pscustomobject]@{}
                    $state | Add-Member -NotePropertyName meta -NotePropertyValue $meta -Force
                }

                $hasClusters = $false
                if ($state.clusters) {
                    if ($state.clusters -is [System.Collections.IDictionary]) {
                        $hasClusters = ($state.clusters.Count -gt 0)
                    }
                    else {
                        $hasClusters = ($state.clusters.PSObject.Properties.Count -gt 0)
                    }
                }

                $baselineProp = "userKubeconfigBaseline"
                $baselineSet = $false
                if ($meta) {
                    if ($meta -is [System.Collections.IDictionary]) {
                        $baselineSet = $meta.Contains($baselineProp) -and -not [string]::IsNullOrWhiteSpace([string]$meta[$baselineProp])
                    }
                    else {
                        $baselineSet = (Test-HasProperty -Object $meta -Name $baselineProp) -and -not [string]::IsNullOrWhiteSpace([string]$meta.$baselineProp)
                    }
                }

                if (-not $hasClusters -and -not $baselineSet -and (Test-Path -LiteralPath $bak)) {
                    if ($meta -is [System.Collections.IDictionary]) {
                        $meta[$baselineProp] = $bak
                        $meta["userKubeconfigBaselineCreatedAt"] = (Get-Date).ToString('o')
                    }
                    else {
                        $meta | Add-Member -NotePropertyName $baselineProp -NotePropertyValue $bak -Force
                        $meta | Add-Member -NotePropertyName "userKubeconfigBaselineCreatedAt" -NotePropertyValue (Get-Date).ToString('o') -Force
                    }
                    Set-StateUnlocked $state
                }
            }
        }
        catch {
            Write-Verbose "Failed to record kubeconfig baseline backup: $($_.Exception.Message)"
        }
    }

    $tmpOut = Join-Path $userKubeDir (".tmp-" + [IO.Path]::GetRandomFileName() + ".yaml")
    try {
        if (Test-IsKubeconfigFile -Path $userCfg) {
            try {
                Merge-KubeconfigFilesToNewFile -InputFiles @($MergedPath, $userCfg) -OutputFile $tmpOut
            }
            catch {
                if ($_.Exception.Message -match 'config\.lock') {
                    [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($userCfg) -WaitSeconds 5)
                    Copy-Item -LiteralPath $MergedPath -Destination $tmpOut -Force
                }
                else {
                    throw
                }
            }
        }
        else {
            Copy-Item -LiteralPath $MergedPath -Destination $tmpOut -Force
        }
        Move-Item -LiteralPath $tmpOut -Destination $userCfg -Force
    }
    finally {
        if (Test-Path -LiteralPath $tmpOut) {
            Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PreferredContext) -and (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        if (-not (Invoke-KubectlUseContextSafe -KubeconfigPath $userCfg -Context $PreferredContext -Retries 2)) {
            if (-not (Set-KubeconfigCurrentContext -Path $userCfg -Context $PreferredContext)) {
                Write-Warning "Failed to set context '$PreferredContext' in $userCfg."
            }
        }
    }

    [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($userCfg) -WaitSeconds 5)

    return $userCfg
}
