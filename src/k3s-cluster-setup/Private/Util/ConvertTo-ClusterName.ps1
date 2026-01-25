function ConvertTo-ClusterName {
    param([string]$Name)
    $n = if ($null -eq $Name) {
        ""
    }
    else {
        $Name
    }
    $n = $n.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($n)) {
        return ""
    }
    if ($n -notmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$') {
        throw "Invalid cluster name '$Name'. Use only [a-z0-9-], and start/end with [a-z0-9]."
    }
    if ($n.Length -gt $script:Limits.ClusterNameMaxLen) {
        throw "Cluster name too long (max $($script:Limits.ClusterNameMaxLen) characters)."
    }
    return $n
}
