function Select-ContextPrompt {
    param([Parameter(Mandatory)][string]$MergedPath)
    $contexts = @()
    try {
        $contexts = ConvertTo-Array (Get-KubeconfigContexts -MergedPath $MergedPath)
    }
    catch {
        Write-Warning ("Failed to read contexts from '{0}': {1}" -f $MergedPath, $_.Exception.Message)
        return $null
    }

    $ctxList = @($contexts)
    if ($ctxList.Count -eq 0) {
        Write-Host "No contexts found." -ForegroundColor Yellow
        return $null
    }

    Write-Host "Select Context" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ctxList.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $ctxList[$i]) -ForegroundColor White
    }
    while ($true) {
        $ans = (Read-Host "Select context number").Trim()
        if ($ans -match '^\d+$') {
            $idx = [int]$ans
            if ($idx -ge 1 -and $idx -le $ctxList.Count) {
                return $ctxList[$idx - 1]
            }
        }
        Write-Host "Invalid selection." -ForegroundColor Yellow
    }
}
