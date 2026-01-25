function Invoke-MultipassLaunchResilient {
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][string[]]$MpArgs,
        [Parameter(Mandatory)][string]$InstanceName
    )
    try {
        Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs $MpArgs | Out-Null
        return
    }
    catch {
        $msg = $_.Exception.Message

        if ($msg -match 'Start-VM' -or $msg -match 'failed to start') {
            try {
                Show-StartVmDiagnostics -InstanceName $InstanceName
            }
            catch {
                Write-NonFatalError $_
            }
        }

        try {
            $list = Get-MultipassListJson -MultipassCmd $MultipassCmd
            $vm = $null
            if ($list -and $list.list) {
                $vm = $list.list | Where-Object { $_.name -eq $InstanceName } | Select-Object -First 1
            }
            if ($vm -and ($vm.state -eq 'Running' -or $vm.state -eq 'Starting')) {
                if ($msg -match 'Timed out|timeout|failed \(exit 5\)') {
                    Write-Warning "Multipass launch timed out, but '$InstanceName' is $($vm.state). Continuing..."
                }
                else {
                    Write-Warning "Multipass launch reported an error, but '$InstanceName' is $($vm.state). Continuing..."
                }
                return
            }
        }
        catch {
            Write-NonFatalError $_
        }
        throw
    }
}
