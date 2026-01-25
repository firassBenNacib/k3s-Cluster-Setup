function Read-YesNo {
    param([Parameter(Mandatory)][string]$Prompt, [Parameter(Mandatory)][bool]$Default)
    $def = if ($Default) {
        "y"
    }
    else {
        "n"
    }
    while ($true) {
        $raw = Read-Host "$Prompt (y/n) [$def]"
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Default
        }
        switch -Regex ($raw.Trim().ToLowerInvariant()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
            default { Write-Host "Please answer y or n." -ForegroundColor Yellow }
        }
    }
}
