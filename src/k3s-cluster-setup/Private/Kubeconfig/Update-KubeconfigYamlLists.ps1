function Update-KubeconfigYamlLists {
    param([Parameter(Mandatory)][string]$KubeconfigPath)

    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return
    }

    try {
        $raw = Get-Content -LiteralPath $KubeconfigPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return
        }

        $raw = $raw -replace "`r`n", "`n" -replace "`r", "`n"
        $raw = $raw -replace '(?m)^clusters:\s*null\s*$', 'clusters: []'
        $raw = $raw -replace '(?m)^contexts:\s*null\s*$', 'contexts: []'
        $raw = $raw -replace '(?m)^users:\s*null\s*$', 'users: []'

        Write-Utf8File -Path $KubeconfigPath -Content ($raw -replace "`n", [Environment]::NewLine)
    }
    catch {
        return
    }
}
