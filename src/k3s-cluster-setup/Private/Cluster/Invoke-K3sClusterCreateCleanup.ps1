function Invoke-K3sClusterCreateCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][bool]$OutputDirCreated,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedVms,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$PlannedVms,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedFiles,
        $ErrorRecord
    )

    Write-Host ""
    $cancelled = [bool]$script:CancelRequested
    if (-not $cancelled -and $ErrorRecord) {
        try {
            if ($ErrorRecord.Exception -is [System.Management.Automation.PipelineStoppedException] -or
                $ErrorRecord.Exception -is [System.OperationCanceledException] -or
                ($ErrorRecord.Exception -and $ErrorRecord.Exception.GetType().FullName -eq 'System.Management.Automation.OperationStoppedException')) {
                $cancelled = $true
            }
        }
        catch {
            Write-NonFatalError $_
        }
    }
    if ($cancelled) {
        Write-Warning "Create cancelled. Cleaning up..."
    }
    else {
        Write-Warning "Create failed. Cleaning up..."
    }

    if (-not $cancelled -and $ErrorRecord) {
        $detail = $null
        try { $detail = $ErrorRecord.Exception.Message } catch { }
        if ([string]::IsNullOrWhiteSpace($detail)) {
            try { $detail = ($ErrorRecord | Out-String).Trim() } catch { }
        }
        if (-not [string]::IsNullOrWhiteSpace($detail)) {
            Write-Warning ("Reason: {0}" -f $detail)
        }
    }

    $wasCancel = $script:CancelRequested
    $script:CancelRequested = $false
    $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $false
    try {
        foreach ($vm in @($CreatedVms)) {
            try {
                Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("stop", "--force", $vm) -AllowNonZero | Out-Null
            }
            catch {
                Write-NonFatalError $_
            }
            try {
                Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("stop", $vm) -AllowNonZero | Out-Null
            }
            catch {
                Write-NonFatalError $_
            }

            try {
                Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("delete", "--purge", $vm) -AllowNonZero | Out-Null
            }
            catch {
                try {
                    Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("delete", $vm) -AllowNonZero | Out-Null
                }
                catch {
                    Write-NonFatalError $_
                }
            }
        }

        Remove-ClusterInstancesBestEffort -MultipassCmd $MultipassCmd -ClusterName $ClusterName -InstanceNames @($PlannedVms) -WaitForAppearSeconds 45 -RetryIntervalSeconds 2
        try {
            Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("purge") -AllowNonZero | Out-Null
        }
        catch {
            Write-NonFatalError $_
        }

        foreach ($f in @($CreatedFiles)) {
            try {
                if ($f -and (Test-Path -LiteralPath $f)) {
                    Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }

        $removeOutputDir = $OutputDirCreated
        if (-not $removeOutputDir) {
            $leaf = Split-Path -Leaf $OutputDir
            if (-not [string]::IsNullOrWhiteSpace($leaf) -and ($leaf -ieq $ClusterName)) {
                $removeOutputDir = $true
            }
        }
        if ($removeOutputDir) {
            try {
                if (Test-Path -LiteralPath $OutputDir) {
                    if (Test-IsSafeClusterArtifactsDir -PathLike $OutputDir) {
                        Remove-Item -LiteralPath $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        $items = Get-ChildItem -LiteralPath $OutputDir -Force -ErrorAction SilentlyContinue
                        if (-not $items -or @($items).Count -eq 0) {
                            Remove-Item -LiteralPath $OutputDir -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }
    }
    finally {
        $script:CancelRequested = $wasCancel
    }
}
