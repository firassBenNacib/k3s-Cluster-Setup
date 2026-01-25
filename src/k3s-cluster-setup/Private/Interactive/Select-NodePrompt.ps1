function Select-NodePrompt {
    param([string]$cluster, [string]$MultipassCmd)

    $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
    $names = @((ConvertTo-Array $inv.Names))
    if ($names.Count -eq 0) {
        Write-Host "No clusters found." -ForegroundColor Yellow
        return ""
    }
    if (-not $inv.Clusters.ContainsKey($cluster)) {
        Write-Host "cluster '$cluster' not found." -ForegroundColor Yellow
        return ""
    }

    $entry = $inv.Clusters[$cluster]
    $nodes = @((ConvertTo-Array (Get-UniqueList -Items ($entry.Servers + $entry.Agents))))
    if ($nodes.Count -eq 0) {
        Write-Host "No nodes found." -ForegroundColor Yellow
        return ""
    }

    Write-Host "Select Node/VM (cluster: $cluster)" -ForegroundColor Cyan
    for ($i = 0; $i -lt $nodes.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $nodes[$i]) -ForegroundColor White
    }

    while ($true) {
        $ans = (Read-Host "Select node number or type exact VM name").Trim()
        if ($nodes -contains $ans) {
            return $ans
        }
        if ($ans -match '^\d+$') {
            $idx = [int]$ans
            if ($idx -ge 1 -and $idx -le $nodes.Count) {
                return $nodes[$idx - 1]
            }
        }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}
