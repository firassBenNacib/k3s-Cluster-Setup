function Resolve-UbuntuImageToVersion {
    param(
        [string]$ImageInput,
        [Parameter(Mandatory)] $Index,
        [Parameter(Mandatory)] [string]$DefaultVersion
    )

    if ([string]::IsNullOrWhiteSpace($ImageInput)) {
        return $DefaultVersion
    }

    $t = $ImageInput.Trim().ToLowerInvariant()

    $t = $t -replace '^\s*ubuntu\s+', ''
    $t = $t -replace '^\s*release:\s*', ''

    if ($Index.AliasToVersion.ContainsKey($t)) {
        return $Index.AliasToVersion[$t]
    }

    return $ImageInput.Trim()
}
