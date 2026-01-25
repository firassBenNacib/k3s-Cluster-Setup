function Invoke-K3sClusterSetupDeleteNode {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [string]$ClusterName,
        [string]$NodeName,
        [switch]$Force,
        [switch]$PurgeFiles,
        [switch]$PurgeMultipass
    )

    if ([string]::IsNullOrWhiteSpace($ClusterName)) {
        $ClusterName = Select-ClusterPrompt -MultipassCmd $MultipassCmd
        if ([string]::IsNullOrWhiteSpace($ClusterName)) { return }
    }
    $ClusterName = ConvertTo-ClusterName -Name $ClusterName

    if ([string]::IsNullOrWhiteSpace($NodeName)) {
        $NodeName = Select-NodePrompt -cluster $ClusterName -MultipassCmd $MultipassCmd
        if ([string]::IsNullOrWhiteSpace($NodeName)) {
            return
        }
    }

    $target = "$ClusterName/$NodeName"
    if (-not $Cmdlet.ShouldProcess($target, 'Delete cluster node')) { return }

    Remove-K3sNode -ClusterName $ClusterName -NodeName $NodeName -Force:$Force -PurgeFiles:$PurgeFiles -PurgeMultipass:$PurgeMultipass -Confirm:$false
}
