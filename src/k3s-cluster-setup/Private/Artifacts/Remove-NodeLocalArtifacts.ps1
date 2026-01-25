function Remove-NodeLocalArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$NodeName,
        [Parameter(Mandatory)][string]$ClusterDir
    )

    $deleted = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($ClusterDir)) { return $deleted }
    $clusterDirResolved = Expand-UserPath $ClusterDir
    if (-not (Test-Path -LiteralPath $clusterDirResolved)) { return $deleted }

    if (-not (Test-IsSafeClusterArtifactsDir -Path $clusterDirResolved)) {
        Write-Warning "Refusing to purge node artifacts because cluster directory does not appear to be safe: $clusterDirResolved"
        return $deleted
    }

    $expectedPaths = @()
    if ($NodeName -match '^k3s-(?<kind>srv\d+|agt\d+)-(?<cluster>.+)$') {
        $kind = $Matches.kind
        $clusterFromNode = $Matches.cluster
        $expectedPaths += (Join-Path -Path $clusterDirResolved -ChildPath ("{0}-{1}-cloud-init.yaml" -f $clusterFromNode, $kind))
        if ($clusterFromNode -ne $ClusterName) {
            $expectedPaths += (Join-Path -Path $clusterDirResolved -ChildPath ("{0}-{1}-cloud-init.yaml" -f $ClusterName, $kind))
        }
    }

    foreach ($p in ($expectedPaths | Select-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p)) {
            try {
                Remove-Item -LiteralPath $p -Force -ErrorAction Stop
                [void]$deleted.Add($p)
            }
            catch {
                Write-NonFatalError $_
            }
        }
    }

    try {
        $files = Get-ChildItem -LiteralPath $clusterDirResolved -File -Filter "*-cloud-init.yaml" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            if ($deleted.Contains($f.FullName)) { continue }
            try {
                $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
                if ($content -match ("(?m)^hostname:\s*{0}\s*$" -f [regex]::Escape($NodeName))) {
                    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                    [void]$deleted.Add($f.FullName)
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    return $deleted
}
