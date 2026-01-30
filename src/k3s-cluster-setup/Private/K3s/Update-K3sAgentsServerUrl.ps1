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
    $scriptTemplateLines = @(
        'set -e',
        'url=__SERVER_URL__',
        'if [ -z "$url" ]; then',
        '  echo "server url is empty" >&2',
        '  exit 1',
        'fi',
        'updated=0',
        'update_env() {',
        '  file="$1"',
        '  if [ -f "$file" ]; then',
        '    if grep -q ''^K3S_URL='' "$file"; then',
        '      sed -i "s|^K3S_URL=.*|K3S_URL=$url|" "$file"',
        '    else',
        '      echo "K3S_URL=$url" >> "$file"',
        '    fi',
        '  else',
        '    printf "K3S_URL=%s\n" "$url" > "$file"',
        '  fi',
        '  updated=1',
        '}',
        'update_env /etc/systemd/system/k3s-agent.service.env',
        'if [ -f /etc/default/k3s-agent ]; then',
        '  update_env /etc/default/k3s-agent',
        'fi',
        'update_yaml() {',
        '  file="$1"',
        '  if [ -f "$file" ]; then',
        '    if grep -q ''^server:'' "$file"; then',
        '      sed -i "s|^server:.*|server: $url|" "$file"',
        '    else',
        '      echo "server: $url" >> "$file"',
        '    fi',
        '  else',
        '    mkdir -p "$(dirname "$file")"',
        '    echo "server: $url" > "$file"',
        '  fi',
        '  updated=1',
        '}',
        'update_yaml /etc/rancher/k3s/config.yaml',
        'update_yaml /etc/rancher/k3s/agent/config.yaml',
        'if [ -f /etc/systemd/system/k3s-agent.service ]; then',
        '  if grep -q ''K3S_URL='' /etc/systemd/system/k3s-agent.service; then',
        '    sed -i "s|K3S_URL=.*|K3S_URL=$url|" /etc/systemd/system/k3s-agent.service',
        '    updated=1',
        '  fi',
        'fi',
        'if [ "$updated" -eq 1 ]; then',
        '  systemctl daemon-reload || true',
        '  systemctl restart k3s-agent || true',
        'fi'
    )
    $scriptTemplate = ($scriptTemplateLines -join "`n")
    $scriptTextFile = $scriptTemplate.Replace("__SERVER_URL__", $serverUrlLiteral)
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
