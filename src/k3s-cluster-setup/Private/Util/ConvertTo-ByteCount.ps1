function ConvertTo-ByteCount {
    param([string]$Size)
    if ($Size -notmatch '^(\d+)([mMgG])$') {
        return $null
    }
    $num = [int]$matches[1]
    $unit = $matches[2].ToUpperInvariant()
    switch ($unit) {
        "M" { return [int64]$num * 1024 * 1024 }
        "G" { return [int64]$num * 1024 * 1024 * 1024 }
        default { return $null }
    }
}
