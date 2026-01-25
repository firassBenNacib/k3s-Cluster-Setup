function Set-KubeconfigCurrentContextPreferred {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [string]$PreferredContext = ""
    )

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return
    }

    $cfg = Get-KubeconfigJson -KubeconfigPath $KubeconfigPath
    if (-not $cfg) {
        Update-KubeconfigIfEmpty -KubeconfigPath $KubeconfigPath
        return
    }

    $ctxNames = @()
    foreach ($c in @(ConvertTo-Array $cfg.contexts)) {
        if ($null -eq $c) { continue }

        $n = $null
        try {
            if ($c -is [string]) {
                $n = [string]$c
            }
            elseif (Test-HasProperty -Object $c -Name 'name') {
                $n = [string]$c.name
            }
        }
        catch {
            $n = $null
        }

        if (-not [string]::IsNullOrWhiteSpace($n)) {
            $ctxNames += $n
        }
    }
    $ctxNames = Get-UniqueList -Items $ctxNames

    $cur = ""
    try {
        $cur = [string]$cfg.'current-context'
    }
    catch {
        $cur = ""
    }
    $cur = ($cur | Out-String).Trim()

    if (@($ctxNames).Count -eq 0) {
        Clear-KubeconfigCurrentContextSafe -KubeconfigPath $KubeconfigPath
        Update-KubeconfigYamlLists -KubeconfigPath $KubeconfigPath
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($cur) -and (@($ctxNames) -contains $cur)) {
        return
    }

    $target = $null
    if (-not [string]::IsNullOrWhiteSpace($PreferredContext) -and (@($ctxNames) -contains $PreferredContext)) {
        $target = $PreferredContext
    }
    else {
        $target = ($ctxNames | Select-Object -First 1)
    }

    if ([string]::IsNullOrWhiteSpace($target)) {
        Clear-KubeconfigCurrentContextSafe -KubeconfigPath $KubeconfigPath
        return
    }

    if (-not (Invoke-KubectlUseContextSafe -KubeconfigPath $KubeconfigPath -Context $target -Retries 2)) {
        [void](Set-KubeconfigCurrentContext -Path $KubeconfigPath -Context $target)
    }

    Update-KubeconfigYamlLists -KubeconfigPath $KubeconfigPath
}
