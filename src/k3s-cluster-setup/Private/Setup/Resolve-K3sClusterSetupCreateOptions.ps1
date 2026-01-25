function Resolve-K3sClusterSetupCreateOptions {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)]$Config
    )

    if ([string]::IsNullOrWhiteSpace($Config.ClusterName)) {
        $Config.ClusterName = New-UniqueClusterName -MultipassCmd $MultipassCmd -Length 6
    }
    $Config.ClusterName = ConvertTo-ClusterName -Name $Config.ClusterName

    $ubuntuIndex = $null
    try {
        $ubuntuIndex = Get-UbuntuImageIndex -MultipassCmd $MultipassCmd
    }
    catch {
        $ubuntuIndex = $null
    }

    $preferredUbuntu = if ($ubuntuIndex) {
        Get-PreferredUbuntuVersion -Index $ubuntuIndex
    }
    else {
        ""
    }

    if ([string]::IsNullOrWhiteSpace($Config.Image)) {
        if ([string]::IsNullOrWhiteSpace($preferredUbuntu)) {
            throw "Unable to determine an Ubuntu image from multipass. Please specify -Image explicitly."
        }
        $Config.Image = $preferredUbuntu
    }

    if ($ubuntuIndex) {
        $Config.Image = Resolve-UbuntuImageToVersion -ImageInput $Config.Image -Index $ubuntuIndex -DefaultVersion $preferredUbuntu

        if ($ubuntuIndex.Versions -and $ubuntuIndex.Versions.Count -gt 0 -and (-not ($ubuntuIndex.Versions -contains $Config.Image))) {
            Write-Warning "Image '$($Config.Image)' not found in multipass find list. This may fail at launch."
        }
    }

    if ($Config.ServerCount -lt 0) {
        $Config.ServerCount = 0
    }
    if ($Config.AgentCount -lt 0) {
        $Config.AgentCount = 1
    }
    if ([string]::IsNullOrWhiteSpace($Config.ServerCpu)) {
        $Config.ServerCpu = "2"
    }
    if ([string]::IsNullOrWhiteSpace($Config.AgentCpu)) {
        $Config.AgentCpu = "1"
    }

    if ($Config.ServerCount -lt $script:Limits.ServerCountMin -or $Config.ServerCount -gt $script:Limits.ServerCountMax) {
        throw "ServerCount must be between $($script:Limits.ServerCountMin) and $($script:Limits.ServerCountMax)."
    }
    if ($Config.AgentCount -lt $script:Limits.AgentCountMin -or $Config.AgentCount -gt $script:Limits.AgentCountMax) {
        throw "AgentCount must be between $($script:Limits.AgentCountMin) and $($script:Limits.AgentCountMax)."
    }

    $Config.ServerCpu = ConvertTo-IntStringInRange -Raw $Config.ServerCpu -Min $script:Limits.CpuMin -Max $script:Limits.CpuMax -Name "ServerCpu"
    $Config.AgentCpu = ConvertTo-IntStringInRange -Raw $Config.AgentCpu -Min $script:Limits.CpuMin -Max $script:Limits.CpuMax -Name "AgentCpu"

    if ([string]::IsNullOrWhiteSpace($Config.ServerMemory)) {
        $Config.ServerMemory = "2G"
    }
    if ([string]::IsNullOrWhiteSpace($Config.AgentMemory)) {
        $Config.AgentMemory = "1G"
    }
    if ([string]::IsNullOrWhiteSpace($Config.ServerDisk)) {
        $Config.ServerDisk = "10G"
    }
    if ([string]::IsNullOrWhiteSpace($Config.AgentDisk)) {
        $Config.AgentDisk = "10G"
    }

    $Config.ServerMemory = ConvertTo-SizeString -Raw $Config.ServerMemory -Kind Memory
    $Config.AgentMemory = ConvertTo-SizeString -Raw $Config.AgentMemory -Kind Memory
    $Config.ServerDisk = ConvertTo-SizeString -Raw $Config.ServerDisk -Kind Disk
    $Config.AgentDisk = ConvertTo-SizeString -Raw $Config.AgentDisk -Kind Disk

    if (Test-ClusterExists -MultipassCmd $MultipassCmd -ClusterName $Config.ClusterName) {
        Write-Warning "Cluster '$($Config.ClusterName)' already exists."
        return $null
    }

    if ($Config.NoKubeconfig) {
        $script:SaveKubeconfig = $false
        $Config.SaveKubeconfig = $false
        $Config.MergeKubeconfig = $false
        $Config.KubeconfigName = ""
        $Config.MergedKubeconfigName = ""
    }
    else {
        $Config.SaveKubeconfig = [bool]$script:SaveKubeconfig
    }

    if ([string]::IsNullOrWhiteSpace($Config.OutputDir)) {
        $clustersRoot = Get-ClustersRoot
        $Config.OutputDir = Join-Path $clustersRoot $Config.ClusterName
    }

    return $Config
}
