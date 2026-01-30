function Get-K3sChannelList {
    param([int]$TimeoutSeconds = 8)

    $baseChannels = @("stable", "latest", "testing")
    $channels = New-Object System.Collections.Generic.List[string]
    foreach ($c in $baseChannels) {
        [void]$channels.Add($c)
    }

    $items = @()
    $uri = "https://update.k3s.io/v1-release/channels"
    $headers = @{ Accept = "application/json" }

    try {
        $prevVerbose = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        try {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
                }
                catch { }
                $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing -Headers $headers -Verbose:$false
            }
            else {
                $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec $TimeoutSeconds -Headers $headers -Verbose:$false
            }
        }
        finally {
            $VerbosePreference = $prevVerbose
        }
        $items = @(Get-ChannelItemsFromResponse -Response $resp)
    }
    catch {
        Write-NonFatalError $_
    }

    if (-not $items -or $items.Count -eq 0) {
        try {
            $prevVerbose = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            try {
                if ($PSVersionTable.PSVersion.Major -lt 6) {
                    $raw = Invoke-WebRequest -Uri $uri -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing -Headers $headers -Verbose:$false
                }
                else {
                    $raw = Invoke-WebRequest -Uri $uri -Method Get -TimeoutSec $TimeoutSeconds -Headers $headers -Verbose:$false
                }
            }
            finally {
                $VerbosePreference = $prevVerbose
            }
            if ($raw -and $raw.Content) {
                $items = @(Get-ChannelItemsFromResponse -Response $raw.Content)
            }
        }
        catch {
            Write-NonFatalError $_
        }
    }

    if ($items -and $items.Count -gt 0) {
        foreach ($item in @($items)) {
            $name = $null
            if ($item -is [string]) {
                $name = $item
            }
            elseif (Test-HasProperty -Object $item -Name "name") {
                $name = [string]$item.name
            }
            elseif (Test-HasProperty -Object $item -Name "id") {
                $name = [string]$item.id
            }

            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }
            $name = $name.Trim()
            if (-not $channels.Contains($name)) {
                [void]$channels.Add($name)
            }
        }
    }
    else {
        Write-Verbose "k3s channel list unavailable; using base channels."
    }

    $filtered = @(
        $channels |
            Where-Object { $_ -and (($_ -in $baseChannels) -or ($_ -notmatch '(?i)-testing$')) }
    )
    $versioned = @(
        $filtered |
            Where-Object { $_ -match '^v\d+\.\d+$' }
    )
    $others = @($filtered | Where-Object { $_ -notmatch '^v\d+\.\d+$' })
    $ordered = New-Object System.Collections.Generic.List[string]
    foreach ($c in $baseChannels) {
        if ($others -contains $c) {
            [void]$ordered.Add($c)
        }
    }
    foreach ($c in $others) {
        if ($baseChannels -notcontains $c) {
            [void]$ordered.Add($c)
        }
    }
    if ($versioned.Count -gt 0) {
        $versioned = @(
            $versioned |
                Sort-Object { [version]$_.TrimStart('v') } -Descending |
                Select-Object -First 4
        )
        foreach ($c in $versioned) {
            [void]$ordered.Add($c)
        }
    }

    return , @($ordered)
}
