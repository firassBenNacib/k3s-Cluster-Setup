function Resolve-StatePath {
    param([Parameter(Mandatory)][string]$FileName)

    if (-not [string]::IsNullOrWhiteSpace($env:K3S_CLUSTER_SETUP_STATE)) {
        $overrideRaw = Expand-UserPath $env:K3S_CLUSTER_SETUP_STATE
        $override = $overrideRaw.Trim()

        $treatAsDir = $false
        if ($override -match '[\\/]$') {
            $treatAsDir = $true
        }
        elseif (Test-Path -LiteralPath $override) {
            try {
                $it = Get-Item -LiteralPath $override -ErrorAction Stop
                if ($it.PSIsContainer) {
                    $treatAsDir = $true
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }

        if ($treatAsDir) {
            $override = Join-Path $override $FileName
        }

        $dir = Split-Path -Parent $override
        if ([string]::IsNullOrWhiteSpace($dir)) {
            $dir = "."
        }

        if (Test-DirectoryWritable -Path $dir) {
            return $override
        }
        throw "K3S_CLUSTER_SETUP_STATE is set but not writable: $override"
    }

    try {
        $clustersRoot = Get-ClustersRoot
        if (-not [string]::IsNullOrWhiteSpace($clustersRoot) -and (Test-DirectoryWritable -Path $clustersRoot)) {
            return (Join-Path $clustersRoot $FileName)
        }
    }
    catch {
        Write-NonFatalError $_
    }

    $scriptDir = $PSScriptRoot

    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $userDir = if ([string]::IsNullOrWhiteSpace($localAppData)) {
        (Join-Path $HOME ".k3s-cluster-setup")
    }
    else {
        (Join-Path $localAppData "k3s-multipass-cluster-manager")
    }

    foreach ($dir in @($userDir, $scriptDir)) {
        if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-DirectoryWritable -Path $dir)) {
            $p = Join-Path $dir $FileName
            Write-Verbose "State path selected: $p"
            return $p
        }
    }

    throw "No writable directory found for state file."
}
