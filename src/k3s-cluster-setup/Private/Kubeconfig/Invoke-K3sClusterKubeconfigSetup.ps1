function Invoke-K3sClusterKubeconfigSetup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$ServerName,
        [Parameter(Mandatory)][string]$ServerIP,
        [Parameter(Mandatory)][string]$OutputDir,
        [AllowEmptyString()][string]$KubeconfigName,
        [AllowEmptyString()][string]$MergedKubeconfigName,
        [Parameter(Mandatory)][bool]$SaveKubeconfig,
        [Parameter(Mandatory)][bool]$MergeKubeconfig,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][int]$RemoteCmdTimeoutSeconds,
        [AllowEmptyString()][string]$OrigKubeEnv,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedFiles
    )

    $kubeconfigFile = $null
    $kubeconfigOrig = $null
    $mergedOut = $null
    $userCfg = $null

    if (-not $SaveKubeconfig) {
        Write-Host "Skipping kubeconfig save (-NoKubeconfig or SaveKubeconfig=false)." -ForegroundColor Yellow
        return [pscustomobject]@{
            KubeconfigFile = $kubeconfigFile
            KubeconfigOrig = $kubeconfigOrig
            MergedOut      = $mergedOut
            UserCfg        = $userCfg
        }
    }

    Stop-IfCancelled
    Write-Host ""
    Write-Host "Retrieving kubeconfig..." -ForegroundColor Green

    $defaultKcName = ("{0}-kubeconfig.yaml" -f $ClusterName)
    $kubeconfigFile = Resolve-OutputPath -PathLike $KubeconfigName -DefaultName $defaultKcName -BaseDir $OutputDir -AddYamlExtension

    $origName = ("{0}-kubeconfig-orig.yaml" -f $ClusterName)
    $orig = Resolve-OutputPath -PathLike $origName -DefaultName $origName -BaseDir $OutputDir -AddYamlExtension

    try {
        $content = Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $ServerName -BashCmd "sudo cat /etc/rancher/k3s/k3s.yaml" `
            -TimeoutSeconds $RemoteCmdTimeoutSeconds
        Write-Utf8File -Path $orig -Content $content
    }
    catch {
        throw ("Failed to retrieve kubeconfig from '{0}': {1}" -f $ServerName, $_.Exception.Message)
    }
    if (-not (Test-Path -LiteralPath $orig)) {
        throw "Failed to retrieve kubeconfig from '$ServerName' (expected file: $orig)."
    }
    [void]$CreatedFiles.Add($orig)
    $kubeconfigOrig = $orig

    $raw = Get-Content -LiteralPath $orig -Raw -ErrorAction Stop
    $raw = Convert-KubeconfigYamlText -Text $raw
    $raw = $raw -replace 'https://127\.0\.0\.1:6443', ("https://{0}:6443" -f $ServerIP)
    $raw = $raw -replace 'https://localhost:6443', ("https://{0}:6443" -f $ServerIP)

    Write-Utf8File -Path $kubeconfigFile -Content $raw
    Set-K3sKubeconfigNames -Path $kubeconfigFile -ClusterName $ClusterName
    [void]$CreatedFiles.Add($kubeconfigFile)

    Write-Host "Kubeconfig updated only" -ForegroundColor Green

    if (-not $MergeKubeconfig) {
        if (-not (Test-HasKubectl)) {
            $env:KUBECONFIG = $kubeconfigFile
            Write-Warning "kubectl not found on host. KUBECONFIG set for current session only: $env:KUBECONFIG"
        }
        else {
            try {
                $userCfg = Update-UserKubeconfigFromMerged -MergedPath $kubeconfigFile -PreferredContext $ClusterName
                $env:KUBECONFIG = $userCfg
                    }
                    catch {
                Write-Warning "Failed to update ~/.kube/config: $($_.Exception.Message)"
                $env:KUBECONFIG = $kubeconfigFile
            }
        }
    }
    else {
        if (-not (Test-HasKubectl)) {
            Write-Warning "kubectl not found on host. Cannot build merged kubeconfig. Using new cluster kubeconfig only."
            $env:KUBECONFIG = $kubeconfigFile
        }
        else {
            $out = $MergedKubeconfigName
            if ([string]::IsNullOrWhiteSpace($out)) {
                $out = "kubeconfig-merged.yaml"
            }
            $desired = Resolve-OutputPath -PathLike $out -DefaultName $out -BaseDir $OutputDir -AddYamlExtension

            $newKcPath = (Resolve-Path -LiteralPath $kubeconfigFile).Path
            $inputs = @($newKcPath)
            $baseList = Resolve-KubeconfigList -KubeEnv $OrigKubeEnv
            foreach ($b in @($baseList)) {
                if (-not $b -or -not (Test-IsKubeconfigFile -Path $b)) {
                    continue
                }
                $bp = (Resolve-Path -LiteralPath $b).Path
                if ($newKcPath -and ($bp -ieq $newKcPath)) {
                    continue
                }
                $inputs += $bp
            }
            $defaultKc = Get-UserKubeconfigFilePath
            if (Test-IsKubeconfigFile -Path $defaultKc) {
                $dp = (Resolve-Path -LiteralPath $defaultKc).Path
                if (-not ($newKcPath -and ($dp -ieq $newKcPath))) {
                    $inputs += $dp
                }
            }
            if (Test-IsKubeconfigFile -Path $desired) {
                $dp2 = (Resolve-Path -LiteralPath $desired).Path
                if (-not ($newKcPath -and ($dp2 -ieq $newKcPath))) {
                    $inputs += $dp2
                }
            }
            $inputs = Get-UniqueListPreserveOrder -Items $inputs

            if (Test-Path -LiteralPath $desired) {
                $stamp = (Get-Date -Format "yyyyMMdd-HHmmss")
                Copy-Item -LiteralPath $desired -Destination "$desired.bak-$stamp" -Force -ErrorAction SilentlyContinue
            }
            $mergedExistedBefore = (Test-Path -LiteralPath $desired)

            $tmpOut = Join-Path (Split-Path -Parent $desired) (".tmp-" + [System.IO.Path]::GetRandomFileName() + ".yaml")
            try {
                Write-Host "Updating merged kubeconfig: $desired" -ForegroundColor Green
                try {
                    Merge-KubeconfigFilesToNewFile -InputFiles $inputs -OutputFile $tmpOut
                }
                catch {
                    if ($_.Exception.Message -match 'config\.lock') {
                        Copy-Item -LiteralPath $kubeconfigFile -Destination $tmpOut -Force
                        Write-Warning "kubeconfig lock detected; merged output contains only the new cluster config."
                    }
                    else {
                        throw
                    }
                }
                Move-Item -LiteralPath $tmpOut -Destination $desired -Force
            }
            finally {
                if (Test-Path -LiteralPath $tmpOut) {
                    Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
                }
            }

            $mergedOut = $desired
            if (-not $mergedExistedBefore) {
                [void]$CreatedFiles.Add($mergedOut)
            }

            if (-not (Invoke-KubectlUseContextSafe -KubeconfigPath $mergedOut -Context $ClusterName -Retries 2)) {
                [void](Set-KubeconfigCurrentContext -Path $mergedOut -Context $ClusterName)
            }

            try {
                $userCfg = Update-UserKubeconfigFromMerged -MergedPath $mergedOut -PreferredContext $ClusterName
                $env:KUBECONFIG = $userCfg
            }
            catch {
                Write-Warning "Failed to update ~/.kube/config: $($_.Exception.Message)"
                $env:KUBECONFIG = $mergedOut
            }

            Write-Host "Merged kubeconfig written to: $mergedOut" -ForegroundColor Green
        }
    }

    if (Test-HasKubectl) {
        try {
            $allowedClusters = Get-ActiveClusterNames -MultipassCmd $MultipassCmd -Include @($ClusterName)
            if (@($allowedClusters).Count -gt 0) {
                if ($mergedOut -and (Test-Path -LiteralPath $mergedOut)) {
                    Remove-KubeconfigStaleClusters -KubeconfigPath $mergedOut -AllowedClusters $allowedClusters
                }
                if ($userCfg -and (Test-Path -LiteralPath $userCfg)) {
                    Remove-KubeconfigStaleClusters -KubeconfigPath $userCfg -AllowedClusters $allowedClusters
                }
            }
        }
        catch {
            Write-Warning "kubeconfig cleanup failed: $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        KubeconfigFile = $kubeconfigFile
        KubeconfigOrig = $kubeconfigOrig
        MergedOut      = $mergedOut
        UserCfg        = $userCfg
    }
}
