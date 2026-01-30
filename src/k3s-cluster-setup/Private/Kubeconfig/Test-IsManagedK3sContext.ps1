function Test-IsManagedK3sContext {
    param([Parameter(Mandatory)]$Ctx)

    try {
        $name = [string]$Ctx.name
        $cluster = [string]$Ctx.context.cluster
        $user = [string]$Ctx.context.user
    }
    catch {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($cluster) -or [string]::IsNullOrWhiteSpace($user)) {
        return $false
    }
    if ($name -ne $cluster -or $name -ne $user) {
        return $false
    }
    if ($name -notmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$') {
        return $false
    }
    if ($name.Length -gt $script:Limits.ClusterNameMaxLen) {
        return $false
    }
    return $true
}
