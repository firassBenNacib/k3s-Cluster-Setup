function Remove-StrayClusterArtifacts {
    param(
        [Parameter(Mandatory)][string]$RootDir,
        [string[]]$AllowedClusters = @()
    )

    $root = Resolve-ExistingDirectoryPath -PathLike $RootDir
    if ([string]::IsNullOrWhiteSpace($root)) {
        return 0
    }

    $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
    $cmp = if ($isWin) {
        [StringComparer]::OrdinalIgnoreCase
    }
    else {
        [StringComparer]::Ordinal
    }
    $allowedSet = New-Object "System.Collections.Generic.HashSet[string]"($cmp)
    foreach ($n in @(Get-UniqueList -Items $AllowedClusters)) {
        [void]$allowedSet.Add($n)
    }

    $pattern = '^(?<name>[a-z0-9]([a-z0-9-]*[a-z0-9])?)-(kubeconfig|kubeconfig-orig|srv\d+-cloud-init|agt\d+-cloud-init)\.ya?ml$'
    $removed = 0

    $dirs = @($root)
    try {
        $dirs += (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    catch {
        Write-NonFatalError $_
    }

    foreach ($dir in @($dirs)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            continue
        }
        try {
            $files = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue
        }
        catch {
            $files = @()
        }

        foreach ($f in @($files)) {
            if ($f.Name -match $pattern) {
                $clusterName = $matches["name"]
                if (-not $allowedSet.Contains($clusterName)) {
                    try {
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        if (-not (Test-Path -LiteralPath $f.FullName)) { $removed++ }
                    }
                    catch {
                        Write-NonFatalError $_
                    }
                }
                continue
            }

            if ($f.Name -ieq '.k3s-multipass-cluster-manager.cluster') {
                $clusterName = (Split-Path -Leaf $dir)
                if (-not [string]::IsNullOrWhiteSpace($clusterName) -and (-not $allowedSet.Contains($clusterName))) {
                    try {
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        if (-not (Test-Path -LiteralPath $f.FullName)) { $removed++ }
                    }
                    catch {
                        Write-NonFatalError $_
                    }
                }
            }
        }
    }

    $cwd = (Get-Location).Path
    foreach ($dir in @($dirs)) {
        $leaf = Split-Path -Leaf $dir
        if ($leaf -notmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$') {
            continue
        }
        if ($allowedSet.Contains($leaf)) {
            continue
        }
        if ($dir -eq $cwd) {
            continue
        }

        $hasArtifact = $false
        try {
            $marker = Get-ClusterArtifactsMarkerPath -ClusterDir $dir
            if ($marker -and (Test-Path -LiteralPath $marker)) {
                $hasArtifact = $true
            }
            else {
                foreach ($ff in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) {
                    if ($ff.Name -match $pattern) { $hasArtifact = $true; break }
                }
            }
        }
        catch {
            $hasArtifact = $false
        }
        if (-not $hasArtifact) {
            try {
                $items = Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                if (-not $items -or @($items).Count -eq 0) {
                    Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-NonFatalError $_
            }
            continue
        }

        try {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-NonFatalError $_
        }
    }

    return $removed
}
