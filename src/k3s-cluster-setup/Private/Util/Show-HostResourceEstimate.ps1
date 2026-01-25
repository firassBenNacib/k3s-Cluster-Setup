function Show-HostResourceEstimate {
    param(
        [Parameter(Mandatory)][int]$ServerCount,
        [Parameter(Mandatory)][int]$AgentCount,
        [Parameter(Mandatory)][string]$ServerMemory,
        [Parameter(Mandatory)][string]$AgentMemory
    )

    $mem = Get-HostMemoryInfo
    if ($null -eq $mem) { return }

    $srv = ConvertTo-ByteCount -Size $ServerMemory
    $agt = ConvertTo-ByteCount -Size $AgentMemory
    if ($null -eq $srv -or $null -eq $agt) { return }

    $totalServers = $ServerCount + 1
    $vmCount = $totalServers + $AgentCount

    $overheadPerVm = 512MB
    $clusterBytes = ($totalServers * $srv) + ($AgentCount * $agt) + ($vmCount * $overheadPerVm)

    $freeGiB = [math]::Round(($mem.FreeBytes / 1GB), 2)
    $totalGiB = [math]::Round(($mem.TotalBytes / 1GB), 2)
    $needGiB = [math]::Round(($clusterBytes / 1GB), 2)

    if ($freeGiB -lt $needGiB) {
        Write-Warning ("Low free RAM for requested cluster: need ~{0} GiB, free ~{1} GiB (host total ~{2} GiB)." -f $needGiB, $freeGiB, $totalGiB)
    }

    if ($VerbosePreference -eq 'Continue') {
        Write-Host ""
        Write-Host "Host Resource Check" -ForegroundColor Cyan
        Write-Host ("  Host RAM (total/free) : {0} GiB / {1} GiB" -f $totalGiB, $freeGiB) -ForegroundColor White
        Write-Host ("  Cluster RAM estimate  : ~{0} GiB ({1} server(s) x {2}, {3} agent(s) x {4})" -f $needGiB, $totalServers, $ServerMemory, $AgentCount, $AgentMemory) -ForegroundColor White
    }

    if ($mem.FreeBytes -lt $clusterBytes) {
        Write-Warning "Low free RAM detected."
    }
}
