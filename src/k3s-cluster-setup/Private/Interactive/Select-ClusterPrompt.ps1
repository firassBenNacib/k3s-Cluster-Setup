function Select-ClusterPrompt {
    param([string]$MultipassCmd)

    $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
    $names = @((ConvertTo-Array $inv.Names))
    if ($names.Count -eq 0) {
        Write-Host "No clusters found." -ForegroundColor Yellow
        return ""
    }

    Write-Host "Select Cluster" -ForegroundColor Cyan
    for ($i = 0; $i -lt $names.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $names[$i]) -ForegroundColor White
    }

    while ($true) {
        $ans = (Read-Host "Select cluster number or type exact cluster name").Trim()
        if ($names -contains $ans) {
            return $ans
        }
        if ($ans -match '^\d+$') {
            $idx = [int]$ans
            if ($idx -ge 1 -and $idx -le $names.Count) {
                return $names[$idx - 1]
            }
        }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}
