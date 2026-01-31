function Update-K3sAgentsServerUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][string[]]$AgentInstances,
        [Parameter(Mandatory)][string]$ServerIp,
        [int]$TimeoutSeconds = 180
    )

    if (-not $AgentInstances -or $AgentInstances.Count -eq 0) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($ServerIp)) {
        Write-Verbose "Update-K3sAgentsServerUrl: ServerIp is empty."
        return $false
    }
    if ($ServerIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        Write-Verbose ("Update-K3sAgentsServerUrl: invalid ServerIp '{0}'." -f $ServerIp)
        return $false
    }

    $serverUrl = "https://$($ServerIp):6443"
    $serverUrlLiteral = ConvertTo-BashSingleQuoted -Value $serverUrl
    $scriptTextFile = Get-TemplateContent -Name "k3s-agent-url.sh.tmpl" -Tokens @{
        SERVER_URL = $serverUrlLiteral
    } -NormalizeLf
    $scriptTextInline = [regex]::Replace($scriptTextFile, "[\r\n]+", "; ")
    $scriptArg = ConvertTo-BashSingleQuoted -Value $scriptTextInline
    $cmd = "sudo /bin/bash -lc $scriptArg"
    $localScriptPath = $null
    try {
        $localScriptPath = Join-Path ([IO.Path]::GetTempPath()) ("k3s-agent-url-" + [IO.Path]::GetRandomFileName() + ".sh")
        Write-Utf8File -Path $localScriptPath -Content $scriptTextFile
    }
    catch {
        $localScriptPath = $null
    }

    $allUpdated = $true

    foreach ($agent in $AgentInstances) {
        if ([string]::IsNullOrWhiteSpace($agent)) { continue }

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $updated = $false
        $lastUpdateOut = $null
        $lastEnvLine = $null
        $lastUpdateError = $null
        $remoteScriptPath = "/tmp/k3s-agent-url.sh"
        while ((Get-Date) -lt $deadline -and -not $updated) {
            $ready = $false
            try {
                $ready = Wait-MultipassInstanceReady -MultipassCmd $MultipassCmd -InstanceName $agent -TimeoutSeconds 30
            }
            catch {
                $ready = $false
            }
            if (-not $ready) {
                Write-Verbose ("Update-K3sAgentsServerUrl: '{0}' not ready yet; attempting update anyway." -f $agent)
            }

            $remaining = [int][Math]::Max(5, ($deadline - (Get-Date)).TotalSeconds)
            $execTimeout = [Math]::Min(30, $remaining)

            $line = $null
            $urlVal = $null
            try {
                $envOut = Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $agent -BashCmd 'sudo cat /etc/systemd/system/k3s-agent.service.env 2>/dev/null' -TimeoutSeconds $execTimeout -AllowNonZero
                $line = Get-K3sUrlLine -EnvOut $envOut
                $urlVal = Get-K3sUrlValue -EnvOut $envOut
            }
            catch {
                $line = $null
                $urlVal = $null
            }
            $lastEnvLine = $line
            if ($urlVal -and $urlVal -eq $serverUrl) {
                $updated = $true
                break
            }

            $updateOut = $null
            try {
                if ($localScriptPath -and (Test-Path -LiteralPath $localScriptPath)) {
                    try {
                        Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("transfer", $localScriptPath, ("{0}:{1}" -f $agent, $remoteScriptPath)) | Out-Null
                        $updateOut = Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $agent -BashCmd ("sudo /bin/bash {0}" -f $remoteScriptPath) -TimeoutSeconds $execTimeout -AllowNonZero
                        $lastUpdateOut = $updateOut
                        Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $agent -BashCmd ("sudo rm -f {0}" -f $remoteScriptPath) -TimeoutSeconds $execTimeout -AllowNonZero | Out-Null
                    }
                    catch {
                        $lastUpdateError = $_.Exception.Message
                    }
                }
                if (-not $updateOut) {
                    $updateOut = Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $agent -BashCmd $cmd -TimeoutSeconds $execTimeout -AllowNonZero
                    $lastUpdateOut = $updateOut
                }
            }
            catch {
                $updateOut = $null
                $lastUpdateError = $_.Exception.Message
            }

            $line = $null
            $urlVal = $null
            try {
                $envOut = Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $agent -BashCmd 'sudo cat /etc/systemd/system/k3s-agent.service.env 2>/dev/null' -TimeoutSeconds $execTimeout -AllowNonZero
                $line = Get-K3sUrlLine -EnvOut $envOut
                $urlVal = Get-K3sUrlValue -EnvOut $envOut
            }
            catch {
                $line = $null
                $urlVal = $null
            }
            $lastEnvLine = $line
            if ($urlVal -and $urlVal -eq $serverUrl) {
                $updated = $true
                break
            }
            if ($updateOut) {
                Write-Verbose ("Update-K3sAgentsServerUrl: update output for '{0}': {1}" -f $agent, (($updateOut | Out-String).Trim()))
            }

            Start-Sleep -Seconds 2
        }

        if (-not $updated) {
            if ($lastEnvLine) {
                Write-Verbose ("Update-K3sAgentsServerUrl: last K3S_URL line for '{0}': {1}" -f $agent, $lastEnvLine)
            }
            if ($lastUpdateOut) {
                $lastUpdateText = (($lastUpdateOut | Out-String).Trim())
                Write-Verbose ("Update-K3sAgentsServerUrl: last update output for '{0}': {1}" -f $agent, $lastUpdateText)
            }
            if ($lastUpdateError) {
                Write-Verbose ("Update-K3sAgentsServerUrl: last update error for '{0}': {1}" -f $agent, $lastUpdateError)
            }
            Write-Verbose ("Update-K3sAgentsServerUrl: failed updating '{0}' after retries." -f $agent)
            $allUpdated = $false
        }
    }
    if ($localScriptPath -and (Test-Path -LiteralPath $localScriptPath)) {
        Remove-Item -LiteralPath $localScriptPath -Force -ErrorAction SilentlyContinue
    }
    return $allUpdated
}
