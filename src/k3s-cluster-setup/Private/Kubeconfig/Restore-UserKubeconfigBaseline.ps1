function Restore-UserKubeconfigBaseline {
    [CmdletBinding()]
    param(

        [switch]$ClearBaseline
    )

    $userCfg = $null
    try { $userCfg = Get-UserKubeconfigFilePath } catch { $userCfg = $null }
    if (-not $userCfg) { return $false }

    $restored = Use-StateFileLock -ScriptBlock {
        $st = Get-StateUnlocked

        if (-not (Test-HasProperty -Object $st -Name "meta") -or -not $st.meta) {
            $st | Add-Member -NotePropertyName meta -NotePropertyValue ([pscustomobject]@{}) -Force
        }

        $baseline = $null
        if ($st.meta -and (Test-HasProperty -Object $st.meta -Name "userKubeconfigBaseline") -and $st.meta.userKubeconfigBaseline) {
            $baseline = [string]$st.meta.userKubeconfigBaseline
        }

        if ($baseline -and (Test-Path -LiteralPath $baseline)) {
            try {

                Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($userCfg) -MinAgeSeconds 60

                Copy-Item -LiteralPath $baseline -Destination $userCfg -Force

                if ($ClearBaseline) {
                    if (Test-HasProperty -Object $st.meta -Name "userKubeconfigBaseline") {
                        [void]$st.meta.PSObject.Properties.Remove("userKubeconfigBaseline")
                    }
                    if (Test-HasProperty -Object $st.meta -Name "userKubeconfigBaselineCreatedAt") {
                        [void]$st.meta.PSObject.Properties.Remove("userKubeconfigBaselineCreatedAt")
                    }

                    $clustersEmpty = $false
                    if ($st.clusters -is [hashtable]) {
                        $clustersEmpty = ($st.clusters.Count -eq 0)
                    }
                    else {
                        $clustersEmpty = ($st.clusters.PSObject.Properties.Count -eq 0)
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
                        try {
                            if (Test-Path -LiteralPath $StatePath) {
                                Remove-Item -LiteralPath $StatePath -Force -ErrorAction Stop
                            }
                        }
                        catch {
                            Write-Verbose ("Failed to remove empty state file '{0}': {1}" -f $StatePath, $_.Exception.Message)
                            Set-StateUnlocked $st
                        }
                    }
                    else {
                        Set-StateUnlocked $st
                    }
                }

                return $true
            }
            catch {
                Write-Verbose ("Failed to restore kubeconfig baseline '{0}' -> '{1}': {2}" -f $baseline, $userCfg, $_.Exception.Message)
                return $false
            }
        }

        return $false
    }

    return $restored
}
