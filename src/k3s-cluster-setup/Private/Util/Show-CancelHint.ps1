function Show-CancelHint {
    if (-not $script:CancelHintShown) {
        Write-Host "Ctrl+C to cancel." -ForegroundColor DarkGray
        $script:CancelHintShown = $true
    }
}
