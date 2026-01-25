function Get-KubeconfigContexts {
    param([Parameter(Mandatory)][string]$MergedPath)
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl not found in PATH."
    }
    $out = Invoke-KubectlConfigReadSafe -KubeconfigPath $MergedPath -KubectlArgs @("config", "get-contexts", "-o", "name") -Retries 2
    if ([string]::IsNullOrWhiteSpace($out)) {
        return @()
    }
    $names = @()
    foreach ($line in ($out | Out-String).Split("`n")) {
        $t = $line.Trim("`r", "`n", " ")
        if (-not [string]::IsNullOrWhiteSpace($t)) {
            $names += $t
        }
    }
    Write-Output -NoEnumerate $names
}
