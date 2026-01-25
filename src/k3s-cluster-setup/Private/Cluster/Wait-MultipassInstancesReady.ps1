function Wait-MultipassInstancesReady {
    param(
        [Parameter(Mandatory=$true)][string]$MultipassCmd,
        [Parameter(Mandatory=$true)][string[]]$InstanceNames,
        [int]$TimeoutSeconds = 120
    )

    $failed = @()
    foreach ($name in @($InstanceNames)) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        if (-not (Wait-MultipassInstanceReady -MultipassCmd $MultipassCmd -InstanceName $name -TimeoutSeconds $TimeoutSeconds)) {
            $failed += $name
        }
    }
    return $failed
}

