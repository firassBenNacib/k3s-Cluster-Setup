function Select-UbuntuImageInteractive {
    param(
        [Parameter(Mandatory)] [string]$MultipassCmd,
        [string]$DefaultImage = ""
    )

    $idx = Get-UbuntuImageIndex -MultipassCmd $MultipassCmd
    $preferred = Get-PreferredUbuntuVersion -Index $idx
    $defaultVersion = Resolve-UbuntuImageToVersion -ImageInput $DefaultImage -Index $idx -DefaultVersion $preferred

    if (-not $idx -or -not $idx.Rows -or $idx.Rows.Count -eq 0) {
        Write-Host ""
        Write-Warning "Could not retrieve an Ubuntu release list from multipass."

        while ($true) {
            $prompt = "Enter release/alias"
            if (-not [string]::IsNullOrWhiteSpace($DefaultImage)) {
                $prompt = "$prompt [$DefaultImage]"
            }
            $ans = Read-Host $prompt
            if ([string]::IsNullOrWhiteSpace($ans)) {
                if (-not [string]::IsNullOrWhiteSpace($DefaultImage)) {
                    return $DefaultImage.Trim()
                }
                continue
            }
            return $ans.Trim()
        }
    }

    Write-Host ""
    Write-Host "Available Ubuntu Releases" -ForegroundColor Cyan

    for ($i = 0; $i -lt $idx.Rows.Count; $i++) {
        $r = $idx.Rows[$i]

        $codename = @($r.Aliases | Where-Object { $_ -notin @("lts", "default", "devel") }) | Select-Object -First 1
        $label = if ($codename) {
            "{0} ({1})" -f $r.Version, $codename
        }
        else {
            $r.Version
        }

        $desc = if ((Test-HasProperty -Object $r -Name "Description") -and $r.Description) {
            " - " + $r.Description
        }
        else {
            ""
        }
        Write-Host ("  {0}. {1}{2}" -f ($i + 1), $label, $desc) -ForegroundColor White
    }

    $defaultIndex = 1
    $pos = [array]::IndexOf($idx.Versions, $defaultVersion)
    if ($pos -ge 0) {
        $defaultIndex = $pos + 1
    }

    Write-Host ""
    Write-Host "You can type a version or an alias." -ForegroundColor DarkGray

    while ($true) {
        $ans = Read-Host ("Select release number or type version/alias [{0}]" -f $defaultIndex)
        if ([string]::IsNullOrWhiteSpace($ans)) {
            return $idx.Versions[$defaultIndex - 1]
        }

        $t = $ans.Trim()

        if ($t -match '^\d+$') {
            $n = [int]$t
            if ($n -ge 1 -and $n -le $idx.Versions.Count) {
                return $idx.Versions[$n - 1]
            }
            Write-Host "Invalid number. Choose between 1 and $($idx.Versions.Count)." -ForegroundColor Yellow
            continue
        }

        $resolved = Resolve-UbuntuImageToVersion -ImageInput $t -Index $idx -DefaultVersion $defaultVersion
        if ($idx.Versions -contains $resolved) {
            return $resolved
        }

        if (Read-YesNo -Prompt "Release '$t' is not in the current multipass list. Use it anyway?" -Default $true) {
            return $t
        }
    }
}
