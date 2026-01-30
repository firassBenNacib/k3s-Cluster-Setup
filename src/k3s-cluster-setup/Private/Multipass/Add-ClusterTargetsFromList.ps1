function Add-ClusterTargetsFromList {
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$Targets,
        [Parameter(Mandatory)][string]$RxNewSrv,
        [Parameter(Mandatory)][string]$RxNewAgt,
        [Parameter(Mandatory)][string]$RxOldSrv,
        [Parameter(Mandatory)][string]$RxOldAgt
    )

    try {
        $listObj = Get-MultipassListJson -MultipassCmd $MultipassCmd
        if (-not $listObj -or -not $listObj.list) {
            return
        }
        foreach ($vm in @($listObj.list)) {
            $n = $vm.name
            if ($n -match $RxNewSrv -or $n -match $RxNewAgt -or $n -match $RxOldSrv -or $n -match $RxOldAgt) {
                [void]$Targets.Add($n)
            }
        }
    }
    catch {
        Write-NonFatalError $_
    }
}
