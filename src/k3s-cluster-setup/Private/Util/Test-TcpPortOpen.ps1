function Test-TcpPortOpen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetHost,
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutMs = 1500
    )

    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient

        $iar = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            try { $client.Close() } catch {}
            return $false
        }

        $client.EndConnect($iar)
        try { $client.Close() } catch {}
        return $true
    }
    catch {
        try { if ($client) { $client.Close() } } catch {}
        return $false
    }
}
