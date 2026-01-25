function Get-UniqueListPreserveOrder {
    param([object[]]$Items)

    $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
    $comparer = if ($isWin) {
        [StringComparer]::OrdinalIgnoreCase
    }
    else {
        [StringComparer]::Ordinal
    }

    $seen = New-Object "System.Collections.Generic.HashSet[string]"($comparer)
    $out = New-Object System.Collections.ArrayList

    foreach ($x in @($Items)) {
        if ($null -eq $x) {
            continue
        }
        $s = $x.ToString()
        if ([string]::IsNullOrWhiteSpace($s)) {
            continue
        }
        if ($seen.Add($s)) {
            [void]$out.Add($s)
        }
    }

    return , @($out)
}
