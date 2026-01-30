function Get-ChannelItemsFromResponse {
    param($Response)
    if ($null -eq $Response) {
        return @()
    }
    if ($Response -is [string]) {
        try {
            $parsed = $Response | ConvertFrom-Json -ErrorAction Stop
            return Get-ChannelItemsFromResponse -Response $parsed
        }
        catch {
            Write-Verbose ("k3s channel response was not JSON: {0}" -f $_.Exception.Message)
            return @()
        }
    }
    if (Test-HasProperty -Object $Response -Name "data") {
        return @($Response.data)
    }
    if (Test-HasProperty -Object $Response -Name "channels") {
        return @($Response.channels)
    }
    return @()
}
