function Remove-KubeconfigStaleClusters {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [string[]]$AllowedClusters = @(),
        [switch]$AllowEmpty
    )

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return
    }

    $allowed = Get-UniqueList -Items $AllowedClusters
    if (@($allowed).Count -eq 0 -and -not $AllowEmpty) {
        return
    }
    [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($KubeconfigPath) -WaitSeconds 5)

    $cfg = Get-KubeconfigJson -KubeconfigPath $KubeconfigPath
    if (-not $cfg -or -not $cfg.contexts) {
        if ($AllowEmpty) {
            Set-KubeconfigCurrentContextPreferred -KubeconfigPath $KubeconfigPath -PreferredContext ""
        }
        return
    }

    $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
    $cmp = if ($isWin) {
        [StringComparer]::OrdinalIgnoreCase
    }
    else {
        [StringComparer]::Ordinal
    }

    $allowedSet = New-Object "System.Collections.Generic.HashSet[string]"($cmp)
    foreach ($n in @($allowed)) {
        [void]$allowedSet.Add($n)
    }

    $keepContexts = New-Object System.Collections.ArrayList
    $removeContexts = New-Object System.Collections.ArrayList
    foreach ($ctx in @($cfg.contexts)) {
        if (-not (Test-IsManagedK3sContext -Ctx $ctx)) {
            [void]$keepContexts.Add($ctx)
            continue
        }

        $clusterName = $ctx.context.cluster
        if (-not [string]::IsNullOrWhiteSpace($clusterName) -and $allowedSet.Contains($clusterName)) {
            [void]$keepContexts.Add($ctx)
        }
        else {
            [void]$removeContexts.Add($ctx)
        }
    }

    $clusterRefs = New-Object "System.Collections.Generic.Dictionary[string,int]"($cmp)
    $userRefs = New-Object "System.Collections.Generic.Dictionary[string,int]"($cmp)

    foreach ($ctx in @($keepContexts)) {
        $c = ""
        $u = ""
        try { $c = [string]$ctx.context.cluster } catch { $c = "" }
        try { $u = [string]$ctx.context.user } catch { $u = "" }

        if (-not [string]::IsNullOrWhiteSpace($c)) {
            if ($clusterRefs.ContainsKey($c)) {
                $clusterRefs[$c]++
            }
            else {
                $clusterRefs[$c] = 1
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($u)) {
            if ($userRefs.ContainsKey($u)) {
                $userRefs[$u]++
            }
            else {
                $userRefs[$u] = 1
            }
        }
    }

    $clustersToRemove = New-Object "System.Collections.Generic.HashSet[string]"($cmp)
    $usersToRemove = New-Object "System.Collections.Generic.HashSet[string]"($cmp)
    foreach ($ctx in @($removeContexts)) {
        $ctxName = $ctx.name
        if (-not [string]::IsNullOrWhiteSpace($ctxName)) {
            Switch-CurrentContextIfMatches -KubeconfigPath $KubeconfigPath -BadContext $ctxName
            [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "delete-context", $ctxName) -Retries 2)
        }
        $c = $ctx.context.cluster
        if (-not [string]::IsNullOrWhiteSpace($c)) {
            [void]$clustersToRemove.Add($c)
        }
        $u = $ctx.context.user
        if (-not [string]::IsNullOrWhiteSpace($u)) {
            [void]$usersToRemove.Add($u)
        }
    }

    foreach ($c in @($clustersToRemove)) {
        if (-not $clusterRefs.ContainsKey($c)) {
            [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "delete-cluster", $c) -Retries 2)
        }
    }
    foreach ($u in @($usersToRemove)) {
        if (-not $userRefs.ContainsKey($u)) {
            [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "delete-user", $u) -Retries 2)
        }
    }

    $preferred = ($allowed | Select-Object -First 1)
    if ($null -eq $preferred) {
        $preferred = ""
    }
    Set-KubeconfigCurrentContextPreferred -KubeconfigPath $KubeconfigPath -PreferredContext $preferred
}
