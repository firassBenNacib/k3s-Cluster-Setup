function ConvertTo-MultipassTableRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Instance
    )

    $name = $Instance.name
    if (-not $name) { $name = $Instance.Name }

    $stateRaw = $Instance.state
    if (-not $stateRaw) { $stateRaw = $Instance.State }

    $state = $stateRaw
    if ($state) {
        switch -Regex ($state.ToString()) {
            '^(?i)running$' { $state = 'Running'; break }
            '^(?i)stopped$' { $state = 'Stopped'; break }
            '^(?i)suspended$' { $state = 'Suspended'; break }
            '^(?i)starting$' { $state = 'Starting'; break }
            default { }
        }
    }

    if ($state -eq 'Starting') {
        $hvState = Get-HyperVStateSafe -VmName $name
        if ($hvState -and ($hvState -match '^(?i)off|saved|paused$')) {
            $state = 'Stopped'
        }
    }

    $ips = $Instance.ipv4
    if ($null -eq $ips) { $ips = $Instance.IPv4 }
    if ($ips -and ($ips -isnot [array])) { $ips = @($ips) }
    if (-not $ips) { $ips = @() }

    $ipv4 = Select-PreferredIPv4 -Ips $ips
    if ([string]::IsNullOrWhiteSpace($ipv4)) { $ipv4 = '--' }

    $release = $Instance.release
    if (-not $release) { $release = $Instance.Release }
    if (-not $release) { $release = $Instance.image }
    if (-not $release) { $release = $Instance.Image }

    $image = ''
    if (-not [string]::IsNullOrWhiteSpace($release)) {
        if ($release -match '^(?i)Ubuntu\s') {
            $image = $release
        }
        else {
            $image = "Ubuntu $release"
        }
    }

    [pscustomobject]@{
        Name  = $name
        State = $state
        IPv4  = $ipv4
        Image = $image
    }
}
