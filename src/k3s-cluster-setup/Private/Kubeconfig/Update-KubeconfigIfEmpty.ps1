function Update-KubeconfigIfEmpty {
    param([Parameter(Mandatory)][string]$KubeconfigPath)

    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return
    }

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Update-KubeconfigYamlLists -KubeconfigPath $KubeconfigPath
        [void](Set-KubeconfigCurrentContext -Path $KubeconfigPath -Context "")
        return
    }

    $ctxs = Get-KubeconfigNameListSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "get-contexts", "-o", "name")
    $clusters = Get-KubeconfigNameListSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "get-clusters")
    $users = Get-KubeconfigNameListSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "get-users")

    if (@($ctxs).Count -eq 0 -and @($clusters).Count -eq 0 -and @($users).Count -eq 0) {
        $skeleton = @"
apiVersion: v1
kind: Config
preferences: {}
clusters: []
users: []
contexts: []
current-context: ""
"@
        Write-Utf8File -Path $KubeconfigPath -Content $skeleton
        return
    }

    $cur = Invoke-KubectlConfigReadSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "current-context") -Retries 2
    $cur = if ($null -eq $cur) {
        ""
    }
    else {
        $cur.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($cur) -and -not (@($ctxs) -contains $cur)) {
        $fallback = ($ctxs | Select-Object -First 1)
        if ($fallback) {
            [void](Invoke-KubectlUseContextSafe -KubeconfigPath $KubeconfigPath -Context $fallback -Retries 2)
        }
        else {
            Clear-KubeconfigCurrentContextSafe -KubeconfigPath $KubeconfigPath
        }
    }

    Update-KubeconfigYamlLists -KubeconfigPath $KubeconfigPath
}
