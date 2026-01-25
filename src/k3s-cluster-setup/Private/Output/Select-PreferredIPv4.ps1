function Select-PreferredIPv4 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Ips
    )

    $ipsNorm = @()
    foreach ($ip in @($Ips)) {
        if ([string]::IsNullOrWhiteSpace($ip)) { continue }
        $v = $ip.Trim()
        if ($v -match '^\d{1,3}(?:\.\d{1,3}){3}$') {
            $ipsNorm += $v
        }
    }

    if ($ipsNorm.Count -eq 0) { return "" }

    $preferred = @(
        $ipsNorm | Where-Object {
            $_ -notmatch '^10\.42\.' -and
            $_ -notmatch '^10\.43\.' -and
            $_ -notmatch '^169\.254\.' -and
            $_ -notmatch '^127\.'
        }
    )
    if ($preferred.Count -gt 0) { return $preferred[0] }

    return $ipsNorm[0]
}
