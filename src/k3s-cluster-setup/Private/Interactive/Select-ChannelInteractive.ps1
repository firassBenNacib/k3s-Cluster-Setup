function Select-ChannelInteractive {
    param(
        [Parameter(Mandatory)] [string[]]$Known,
        [string]$DefaultChannel = "stable"
    )

    Write-Host ""
    Write-Host "k3s Channels" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Known.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $Known[$i])
    }

    $defaultIndex = 1
    if ($Known -contains $DefaultChannel) {
        $defaultIndex = [int]([array]::IndexOf($Known, $DefaultChannel) + 1)
    }

    Write-Host ""
    Write-Host "Enter a number to select, or type a custom channel." -ForegroundColor DarkGray

    while ($true) {
        $ans = Read-Host ("Select channel number or type channel [{0}]" -f $defaultIndex)

        if ([string]::IsNullOrWhiteSpace($ans)) {
            return $Known[$defaultIndex - 1]
        }

        $t = $ans.Trim()
        if ($t -match '^\d+$') {
            $idx = [int]$t
            if ($idx -ge 1 -and $idx -le $Known.Count) {
                return $Known[$idx - 1]
            }
            Write-Host "Invalid number. Choose between 1 and $($Known.Count)." -ForegroundColor Yellow
            continue
        }

        if ($Known -contains $t) {
            return $t
        }
        if (Read-YesNo -Prompt "Channel '$t' is not in the list. Use it anyway?" -Default $true) {
            return $t
        }
    }
}
