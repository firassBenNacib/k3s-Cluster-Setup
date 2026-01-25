function Write-NonFatalError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    if (-not $ErrorRecord) {
        Write-Verbose "Non-fatal error suppressed."
        return
    }

    $message = $null
    try { $message = $ErrorRecord.Exception.Message } catch { }
    if ([string]::IsNullOrWhiteSpace($message)) {
        try { $message = ($ErrorRecord | Out-String).Trim() } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "Unknown error"
    }

    Write-Verbose ("Non-fatal error suppressed: {0}" -f $message)
}
