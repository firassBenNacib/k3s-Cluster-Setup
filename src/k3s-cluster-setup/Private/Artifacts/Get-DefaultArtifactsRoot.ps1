function Get-DefaultArtifactsRoot {

    if (-not [string]::IsNullOrWhiteSpace($env:K3S_CLUSTER_SETUP_ARTIFACTS_ROOT)) {
        try {
            return (Resolve-OutputDirectory -PathLike $env:K3S_CLUSTER_SETUP_ARTIFACTS_ROOT)
        }
        catch {
            Write-NonFatalError $_
        }
    }

    try {
        $repoRoot = Get-RepoRoot
        if (-not [string]::IsNullOrWhiteSpace($repoRoot) -and (Test-DirectoryWritable -Path $repoRoot)) {
            return $repoRoot
        }
    }
    catch {
        Write-NonFatalError $_
    }

    $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')

    if ($isWin -and $env:LOCALAPPDATA) {
        $root = Join-Path $env:LOCALAPPDATA 'k3s-multipass-cluster-manager'
    }
    elseif ($env:XDG_DATA_HOME) {
        $root = Join-Path $env:XDG_DATA_HOME 'k3s-multipass-cluster-manager'
    }
    else {
        $homeDir = $HOME
        if ([string]::IsNullOrWhiteSpace($homeDir)) {
            $homeDir = (Get-Location).Path
        }
        $root = Join-Path $homeDir '.k3s-multipass-cluster-manager'
    }

    try {
        if (-not (Test-Path -LiteralPath $root)) {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
        }
    }
    catch {

        $root = (Get-Location).Path
    }

    return $root
}
