function Set-KubeconfigCurrentContext {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Context
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop

        $raw = $raw -replace '(?m)^clusters:\s*null\s*$', 'clusters: []'
        $raw = $raw -replace '(?m)^contexts:\s*null\s*$', 'contexts: []'
        $raw = $raw -replace '(?m)^users:\s*null\s*$', 'users: []'

        $ctxYaml = if ([string]::IsNullOrEmpty($Context)) {
            '""'
        }
        else {
            $Context
        }
        if ($raw -match '(?m)^current-context:\s*') {
            $raw = [regex]::Replace($raw, '(?m)^current-context:\s*.*$', "current-context: $ctxYaml")
        }
        else {
            $raw = $raw.TrimEnd() + [Environment]::NewLine + "current-context: $ctxYaml" + [Environment]::NewLine
        }
        Write-Utf8File -Path $Path -Content $raw
        return $true
    }
    catch {
        return $false
    }
}
