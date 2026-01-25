function Read-IntInRange {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][int]$Default,
        [Parameter(Mandatory)][int]$Min,
        [Parameter(Mandatory)][int]$Max
    )
    while ($true) {
        $raw = Read-Host "$Prompt [$Default]"
        if ($null -ne $raw) {
            $raw = $raw.Trim()
        }
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Default
        }
        if ($raw -notmatch '^\d+$') {
            Write-Host "Please enter a number." -ForegroundColor Yellow; continue
        }
        $v = [int]$raw
        if ($v -lt $Min -or $v -gt $Max) {
            Write-Host "Value must be between $Min and $Max." -ForegroundColor Yellow; continue
        }
        return $v
    }
}
