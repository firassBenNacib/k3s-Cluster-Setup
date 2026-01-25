function Disable-CancelHandler {
    param($Handler)
    if ($Handler) {
        try {
            [Console]::remove_CancelKeyPress($Handler)
        }
        catch {
            Write-NonFatalError $_
        }
    }
}
