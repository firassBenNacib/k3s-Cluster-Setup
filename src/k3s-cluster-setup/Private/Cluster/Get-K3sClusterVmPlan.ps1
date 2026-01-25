function Get-K3sClusterVmPlan {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][int]$ServerCount,
        [Parameter(Mandatory)][int]$AgentCount
    )

    $primaryServer = Get-NewServerName -cluster $ClusterName -index 1
    $serverNames = @($primaryServer)
    for ($i = 2; $i -le ($ServerCount + 1); $i++) {
        $serverNames += Get-NewServerName -cluster $ClusterName -index $i
    }

    $agentNames = @()
    for ($i = 1; $i -le $AgentCount; $i++) {
        $agentNames += Get-NewAgentName -cluster $ClusterName -index $i
    }

    return [pscustomobject]@{
        PrimaryServer = $primaryServer
        ServerNames   = $serverNames
        AgentNames    = $agentNames
    }
}
