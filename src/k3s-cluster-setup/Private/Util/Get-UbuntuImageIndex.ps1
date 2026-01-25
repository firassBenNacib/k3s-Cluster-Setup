function Get-UbuntuImageIndex {
    param([Parameter(Mandatory)] [string]$MultipassCmd)

    $rows = New-Object System.Collections.ArrayList

    function Get-RowValue {
        param([Parameter(Mandatory)]$Row, [Parameter(Mandatory)][string]$Name)

        if ($null -eq $Row) {
            return $null
        }
        if (Test-HasProperty -Object $Row -Name $Name) {
            return $Row.$Name
        }
        return $null
    }

    function Add-Row {
        param([string]$Image, [string]$Aliases, [string]$Description)

        if ([string]::IsNullOrWhiteSpace($Image)) {
            return
        }

        $img = $Image.Trim()
        if ($img -like 'daily:*') {
            return
        }
        if ($img -notmatch '^\d{2}\.\d{2}$') {
            return
        }

        $desc = if ($null -eq $Description) {
            ""
        }
        else {
            $Description.Trim()
        }
        if ($desc -notmatch '^Ubuntu\s') {
            return
        }
        if ($desc -match '^Ubuntu\s+Core') {
            return
        }

        $als = @()
        if (-not [string]::IsNullOrWhiteSpace($Aliases)) {
            $als = @(
                $Aliases.Split(',') |
                    ForEach-Object { $_.Trim().ToLowerInvariant() } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }

        [void]$rows.Add([pscustomobject]@{
                Version     = $img
                Aliases     = $als
                Description = $desc
            })
    }

    $csvParsed = $false
    $csvAdded = $false
    try {
        $raw = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("find", "--format", "csv")
        $text = ($raw | Out-String).Trim()

        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $csvParsed = $true
            $before = $rows.Count
            $csv = $text | ConvertFrom-Csv
            foreach ($r in @($csv)) {
                $imgRaw = Get-RowValue -Row $r -Name "Image"
                $aliases = Get-RowValue -Row $r -Name "Aliases"
                $desc = Get-RowValue -Row $r -Name "Description"
                $verRaw = Get-RowValue -Row $r -Name "Version"

                $img = $imgRaw
                $ver = $null
                if ($img -match '^\d{2}\.\d{2}$') {
                    $ver = $img
                }
                elseif ($verRaw -match '(\d{2}\.\d{2})') {
                    $ver = $Matches[1]
                }

                if ($ver) {
                    $img = $ver
                    if (-not [string]::IsNullOrWhiteSpace($imgRaw) -and $imgRaw -ne $ver -and $imgRaw -notmatch '^\d{2}\.\d{2}$') {
                        $aliases = if ([string]::IsNullOrWhiteSpace($aliases)) { $imgRaw } else { "$aliases,$imgRaw" }
                    }
                }

                Add-Row -Image $img -Aliases $aliases -Description $desc
            }
            if ($rows.Count -gt $before) {
                $csvAdded = $true
            }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    if ($rows.Count -eq 0) {
        try {
            $raw2 = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("find")
            $lines = ($raw2 | Out-String).Split("`n") | ForEach-Object { $_.TrimEnd("`r") }

            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                if ($line -match '^\s*Image\s+Aliases\s+Version\s+Description\s*$') {
                    continue
                }
                if ($line -match '^-+\s*$') {
                    continue
                }

                $cols = $line -split '\s{2,}'
                if ($cols.Count -lt 3) {
                    continue
                }

                if ($cols.Count -eq 3) {
                    Add-Row -Image $cols[0] -Aliases "" -Description $cols[2]
                }
                else {
                    Add-Row -Image $cols[0] -Aliases $cols[1] -Description $cols[3]
                }
            }
        }
        catch {
            Write-NonFatalError $_
        }
    }

    if ($rows.Count -eq 0) {
        if ($csvParsed -and -not $csvAdded) {
            Write-Verbose "multipass find output could not be parsed; no Ubuntu releases were detected."
        }
    }

    $byVersion = @{}
    foreach ($r in @($rows)) {
        if (-not $byVersion.ContainsKey($r.Version)) {
            $byVersion[$r.Version] = $r
        }
    }

    $finalRows = @(
        $byVersion.Values |
            Sort-Object { [version]$_.Version } -Descending
    )

    $versions = @($finalRows | ForEach-Object { $_.Version })

    $aliasMap = @{}
    foreach ($r in $finalRows) {
        $aliasMap[$r.Version.ToLowerInvariant()] = $r.Version
        foreach ($a in @($r.Aliases)) {
            if (-not $aliasMap.ContainsKey($a)) {
                $aliasMap[$a] = $r.Version
            }
        }
    }

    return [pscustomobject]@{
        Rows           = $finalRows
        Versions       = $versions
        AliasToVersion = $aliasMap
    }
}
