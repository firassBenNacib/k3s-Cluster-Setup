function ConvertTo-SizeString {
    param(
        [Parameter(Mandatory)][string]$Raw,
        [Parameter(Mandatory)][ValidateSet("Memory", "Disk")][string]$Kind
    )
    $s = if ($null -eq $Raw) {
        ""
    }
    else {
        $Raw
    }
    $s = $s.Trim()
    if ([string]::IsNullOrWhiteSpace($s)) {
        return ""
    }
    if ($s -match '^\d+$') {
        $s = "$s" + "G"
    }
    $s = $s.ToUpperInvariant()
    $s = $s -replace 'GB$', 'G'
    $s = $s -replace 'MB$', 'M'
    $kindLabel = $Kind.ToLowerInvariant()
    $formatHint = if ($Kind -eq "Disk") { "5G, 20G, 100G" } else { "512M, 1G, 2G" }

    if ($s -notmatch '^\d+[MG]$') {
        throw ("Please enter a {0} size like {1} (you entered '{2}')." -f $kindLabel, $formatHint, $Raw)
    }
    $bytes = ConvertTo-ByteCount -Size $s
    if ($null -eq $bytes) {
        throw ("Please enter a {0} size like {1} (you entered '{2}')." -f $kindLabel, $formatHint, $Raw)
    }
    if ($Kind -eq "Memory") {
        $minBytes = $script:Limits.MemoryMinBytes
        $maxBytes = $script:Limits.MemoryMaxBytes
        if ($bytes -lt $script:Limits.MemoryMinBytes -or $bytes -gt $script:Limits.MemoryMaxBytes) {
            $minLabel = if ($minBytes % 1GB -eq 0) { "{0}G" -f ($minBytes / 1GB) } elseif ($minBytes % 1MB -eq 0) { "{0}M" -f ($minBytes / 1MB) } else { "$minBytes bytes" }
            $maxLabel = if ($maxBytes % 1GB -eq 0) { "{0}G" -f ($maxBytes / 1GB) } elseif ($maxBytes % 1MB -eq 0) { "{0}M" -f ($maxBytes / 1MB) } else { "$maxBytes bytes" }
            throw ("Please enter a {0} size between {1} and {2} (you entered '{3}')." -f $kindLabel, $minLabel, $maxLabel, $s)
        }
    }
    else {
        $minBytes = $script:Limits.DiskMinBytes
        $maxBytes = $script:Limits.DiskMaxBytes
        if ($bytes -lt $script:Limits.DiskMinBytes -or $bytes -gt $script:Limits.DiskMaxBytes) {
            $minLabel = if ($minBytes % 1GB -eq 0) { "{0}G" -f ($minBytes / 1GB) } elseif ($minBytes % 1MB -eq 0) { "{0}M" -f ($minBytes / 1MB) } else { "$minBytes bytes" }
            $maxLabel = if ($maxBytes % 1GB -eq 0) { "{0}G" -f ($maxBytes / 1GB) } elseif ($maxBytes % 1MB -eq 0) { "{0}M" -f ($maxBytes / 1MB) } else { "$maxBytes bytes" }
            throw ("Please enter a {0} size between {1} and {2} (you entered '{3}')." -f $kindLabel, $minLabel, $maxLabel, $s)
        }
    }
    return $s
}
