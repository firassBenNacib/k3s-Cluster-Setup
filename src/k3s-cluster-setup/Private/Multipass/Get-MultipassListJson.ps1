function Get-MultipassListJson {
    param([string]$MultipassCmd)
    $raw = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("list", "--format", "json") -TimeoutSeconds 15 -AllowNonZero
    $text = ($raw | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "multipass list --format json returned no output."
    }
    try {
        $obj = ($text | ConvertFrom-Json)
    }
    catch {
        throw ("multipass list --format json returned invalid JSON: {0}" -f $text)
    }
    if ($null -eq $obj) {
        throw "multipass list --format json returned empty output."
    }
    if ($obj -isnot [System.Array] -and -not (Test-HasProperty -Object $obj -Name "list")) {
        throw "multipass list JSON did not include a 'list' property."
    }
    if ($obj -is [System.Array]) {
        $obj = [pscustomobject]@{ list = $obj }
    }
    if ($null -eq $obj.list) {
        $obj.list = @()
    }
    elseif ($obj.list -isnot [System.Array]) {
        $obj.list = @($obj.list)
    }
    return $obj
}
