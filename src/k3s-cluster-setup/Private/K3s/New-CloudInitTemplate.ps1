function New-CloudInitTemplate {
    param(
        [Parameter(Mandatory)][string]$Hostname,
        [string]$Channel,
        [string]$K3sVersion,
        [string]$ServerToken,
        [string]$AgentToken,
        [string]$ServerIP,
        [bool]$IsAgent,
        [string]$ServerExec,
        [string]$AgentExec
    )
    $safeChannel = ConvertTo-BashSingleQuoted -Value $Channel
    $safeK3sVersion = ConvertTo-BashSingleQuoted -Value $K3sVersion
    $safeServerToken = ConvertTo-BashSingleQuoted -Value $ServerToken
    $safeAgentToken = ConvertTo-BashSingleQuoted -Value $AgentToken
    $safeServerExec = ConvertTo-BashSingleQuoted -Value $ServerExec
    $safeAgentExec = ConvertTo-BashSingleQuoted -Value $AgentExec
    $versionEnv = ""
    if (-not [string]::IsNullOrWhiteSpace($K3sVersion)) {
        $versionEnv = " INSTALL_K3S_VERSION=$safeK3sVersion"
    }

    if ($IsAgent) {
        return @"
#cloud-config
hostname: $Hostname
manage_etc_hosts: true
package_update: false
package_upgrade: false
runcmd:
  - [ bash, -lc, "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=$safeChannel$versionEnv K3S_TOKEN=$safeAgentToken K3S_URL=https://${ServerIP}:6443 INSTALL_K3S_EXEC=$safeAgentExec sh -" ]
"@
    }

    return @"
#cloud-config
hostname: $Hostname
manage_etc_hosts: true
package_update: false
package_upgrade: false
runcmd:
  - [ bash, -lc, "curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=$safeChannel$versionEnv K3S_TOKEN=$safeServerToken K3S_AGENT_TOKEN=$safeAgentToken K3S_KUBECONFIG_MODE=644 INSTALL_K3S_EXEC=$safeServerExec sh -" ]
"@
}
