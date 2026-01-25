function Initialize-NewK3sClusterContext {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][int]$ServerCount
    )

    $outInfo = Resolve-OutputDirectoryWithCreated -PathLike $OutputDir
    $resolvedOutputDir = $outInfo.Path
    $outputDirCreated = [bool]$outInfo.Created
    $multipass = Get-MultipassCmd
    $useClusterInit = ($ServerCount -gt 0)
    $origKubeEnv = $env:KUBECONFIG
    $cancelHandler = $null
    Enable-CancelHandler -Handler ([ref]$cancelHandler)

    $createdVms = New-Object System.Collections.Generic.List[string]
    $createdFiles = New-Object System.Collections.Generic.List[string]
    $plannedVms = New-Object System.Collections.Generic.List[string]

    $markerPath = Get-ClusterArtifactsMarkerPath -ClusterDir $resolvedOutputDir
    try {
        Set-Content -LiteralPath $markerPath -Value ("cluster={0}`ncreated={1}`n" -f $ClusterName, (Get-Date).ToString("o")) -Encoding UTF8 -Force
        $createdFiles.Add($markerPath) | Out-Null
    }
    catch {
        Write-Warning ("Could not write cluster artifacts marker file: {0}" -f $markerPath)
    }

    return [pscustomobject]@{
        OutputDir        = $resolvedOutputDir
        OutputDirCreated = $outputDirCreated
        MultipassCmd     = $multipass
        UseClusterInit   = $useClusterInit
        OrigKubeEnv      = $origKubeEnv
        CancelHandler    = $cancelHandler
        CreatedVms       = $createdVms
        CreatedFiles     = $createdFiles
        PlannedVms       = $plannedVms
    }
}
