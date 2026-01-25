function Get-PreferredUbuntuVersion {
    param([Parameter(Mandatory)] $Index)

    if ($Index.AliasToVersion.ContainsKey("default")) {
        return $Index.AliasToVersion["default"]
    }

    if ($Index.AliasToVersion.ContainsKey("lts")) {
        return $Index.AliasToVersion["lts"]
    }

    if ($Index.Versions.Count -gt 0) {
        return $Index.Versions[0]
    }

    return ""
}
