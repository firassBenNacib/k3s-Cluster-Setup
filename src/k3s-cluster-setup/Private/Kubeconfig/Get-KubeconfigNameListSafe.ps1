function Get-KubeconfigNameListSafe {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [Parameter(Mandatory)][string[]]$KubectlArgs
    )

    $raw = Invoke-KubectlConfigReadSafe -KubeconfigPath $KubeconfigPath -KubectlArgs $KubectlArgs -Retries 2
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    return @(
        $raw.Split("`n") |
            ForEach-Object { $_.Trim("`r", " ", "`t") } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}
