function Update-KubeconfigServerAddressInFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ServerHost,

        [Parameter(Mandatory = $false)]
        [int]$Port = 6443
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $targetUrl = "https://$ServerHost`:$Port"

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch {
        Write-Verbose "Failed to read kubeconfig: $Path"
        return $false
    }

    $updated = [regex]::Replace(
        $raw,
        '(?m)^(?<indent>\s*)server:\s*https://[^\s]+',
        ('${indent}server: ' + $targetUrl)
    )

    if ($updated -eq $raw) {
        return $false
    }

    try {
        Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Verbose "Failed to write kubeconfig: $Path"
        return $false
    }

    return $true
}
