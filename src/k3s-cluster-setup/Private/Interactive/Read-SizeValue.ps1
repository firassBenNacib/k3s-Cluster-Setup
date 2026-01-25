function Read-SizeValue {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$Default,
        [Parameter(Mandatory)][ValidateSet("Memory", "Disk")][string]$Kind
    )
    while ($true) {
        $raw = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Default
        }
        try {
            return (ConvertTo-SizeString -Raw $raw -Kind $Kind)
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    }
}
