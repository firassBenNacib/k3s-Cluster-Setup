function Add-UbuntuImageIndexRow {
    param(
        [Parameter(Mandatory)][System.Collections.IList]$Rows,
        [string]$Image,
        [string]$Aliases,
        [string]$Description
    )

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

    [void]$Rows.Add([pscustomobject]@{
            Version     = $img
            Aliases     = $als
            Description = $desc
        })
}
