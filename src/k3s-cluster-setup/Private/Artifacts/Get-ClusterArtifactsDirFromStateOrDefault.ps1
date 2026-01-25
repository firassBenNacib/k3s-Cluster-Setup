function Get-ClusterArtifactsDirFromStateOrDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClusterName
    )

    try {
        $state = Get-State
        if ($state -and $state.clusters -and ($state.clusters -is [hashtable]) -and $state.clusters.ContainsKey($ClusterName)) {
            $e = $state.clusters[$ClusterName]
            if ($e -and (Test-HasProperty -Object $e -Name "outputDir") -and $e.outputDir) {
                $dir = Expand-UserPath $e.outputDir
                if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
                    return $dir
                }
            }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    return (Get-ClusterArtifactsDir -ClusterName $ClusterName)
}
