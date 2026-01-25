function Invoke-MpTimeoutBash {
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][string]$InstanceName,
        [Parameter(Mandatory)][string]$BashCmd,
        [int]$TimeoutSeconds = 20,
        [switch]$AllowNonZero
    )
    Stop-IfCancelled
    $useTimeout = ($TimeoutSeconds -gt 0)
    $mpArgs = if ($useTimeout) {
        @("exec", $InstanceName, "--", "timeout", ("{0}s" -f $TimeoutSeconds), "/bin/bash", "-lc", $BashCmd)
    }
    else {
        @("exec", $InstanceName, "--", "/bin/bash", "-lc", $BashCmd)
    }

    try {
        $result = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs $mpArgs -AllowNonZero:$AllowNonZero
    }
    catch {
        if ($useTimeout -and $_.Exception.Message -match '(?i)timeout.*(not found|No such file)') {
            $mpArgs = @("exec", $InstanceName, "--", "/bin/bash", "-lc", $BashCmd)
            $result = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs $mpArgs -AllowNonZero:$AllowNonZero
        }
        else {
            throw
        }
    }

    if ($useTimeout -and $AllowNonZero) {
        $outText = ($result | Out-String)
        if ($outText -match '(?i)timeout.*(not found|No such file)') {
            $mpArgs = @("exec", $InstanceName, "--", "/bin/bash", "-lc", $BashCmd)
            $result = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs $mpArgs -AllowNonZero:$AllowNonZero
        }
    }
    Stop-IfCancelled
    return $result
}
