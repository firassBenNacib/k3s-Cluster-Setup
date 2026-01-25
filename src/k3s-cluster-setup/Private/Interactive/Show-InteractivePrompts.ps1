function Show-InteractivePrompts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,

        [string]$ClusterName = "",
        [bool]$ClusterNameWasProvided = $false,

        [string]$Channel = "stable",
        [AllowEmptyString()][string]$K3sVersion = "",
        [string]$Image = "",

        [int]$ServerCount = -1,
        [int]$AgentCount = -1,

        [string]$ServerCpu = "",
        [string]$AgentCpu = "",
        [string]$ServerDisk = "",
        [string]$AgentDisk = "",
        [string]$ServerMemory = "",
        [string]$AgentMemory = "",

        [switch]$DisableFlannel,

        [bool]$SaveKubeconfig = $true,
        [switch]$NoKubeconfig,
        [switch]$MergeKubeconfig,
        [string]$KubeconfigName = "",
        [string]$MergedKubeconfigName = "",
        [string]$OutputDir = "",

        [switch]$KeepCloudInit,

        [int]$LaunchTimeoutSeconds = 900,
        [switch]$Minimal,
        [int]$RemoteCmdTimeoutSeconds = 20,
        [int]$ApiReadyTimeoutSeconds = 900,
        [int]$NodeRegisterTimeoutSeconds = 900,
        [int]$NodeReadyTimeoutSeconds = 1800,
        [switch]$DisableTraefik,
        [switch]$DisableServiceLB,
        [switch]$DisableMetricsServer
    )

    Write-Host ""
    Write-Host "(Enter = default)" -ForegroundColor DarkGray

    $cluster = $ClusterName
    while ($true) {
        if ([string]::IsNullOrWhiteSpace($cluster)) {
            $rawName = (Read-Host "Enter cluster name (press Enter for random)")
            if ([string]::IsNullOrWhiteSpace($rawName) -or $rawName.Trim() -match '^(random|rand|r)$') {
                $cluster = New-UniqueClusterName -MultipassCmd $MultipassCmd -Length 6
                Write-Host "Generated cluster name: $cluster" -ForegroundColor Green
            }
            else {
                try {
                    $cluster = ConvertTo-ClusterName -Name $rawName.Trim()
                }
                catch {
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                    $cluster = ""
                    continue
                }
            }
        }
        else {
            $cluster = ConvertTo-ClusterName -Name $cluster
        }

        if (Test-ClusterExists -MultipassCmd $MultipassCmd -ClusterName $cluster) {
            if ($ClusterNameWasProvided) {
                throw "Cluster '$cluster' already exists. Choose a different name."
            }
            Write-Host "Cluster '$cluster' already exists. Please choose another name." -ForegroundColor Yellow
            $cluster = ""
            continue
        }
        break
    }

    $defServerCount = if ($ServerCount -ge 0) { $ServerCount } else { 0 }
    $defAgentCount = if ($AgentCount -ge 0) { $AgentCount } else { 1 }

    Write-Host ""
    $ServerCount = Read-IntInRange -Prompt "Extra servers" -Default $defServerCount -Min $script:Limits.ServerCountMin -Max $script:Limits.ServerCountMax
    $AgentCount = Read-IntInRange -Prompt "Workers"       -Default $defAgentCount  -Min $script:Limits.AgentCountMin  -Max $script:Limits.AgentCountMax

    $defServerCpu = 2
    if (-not [string]::IsNullOrWhiteSpace($ServerCpu)) {
        $tmp = 0
        if ([int]::TryParse($ServerCpu, [ref]$tmp)) { $defServerCpu = $tmp }
    }

    $defAgentCpu = 1
    if (-not [string]::IsNullOrWhiteSpace($AgentCpu)) {
        $tmp = 0
        if ([int]::TryParse($AgentCpu, [ref]$tmp)) { $defAgentCpu = $tmp }
    }

    $defServerMem = if ([string]::IsNullOrWhiteSpace($ServerMemory)) { "2G" } else { $ServerMemory }
    $defAgentMem = if ([string]::IsNullOrWhiteSpace($AgentMemory)) { "1G" } else { $AgentMemory }
    $defServerDisk = if ([string]::IsNullOrWhiteSpace($ServerDisk)) { "10G" } else { $ServerDisk }
    $defAgentDisk = if ([string]::IsNullOrWhiteSpace($AgentDisk)) { "10G" } else { $AgentDisk }

    Write-Host ""
    $scpu = Read-IntInRange -Prompt "Server CPU" -Default $defServerCpu -Min $script:Limits.CpuMin -Max $script:Limits.CpuMax
    $acpu = Read-IntInRange -Prompt "Worker CPU" -Default $defAgentCpu  -Min $script:Limits.CpuMin -Max $script:Limits.CpuMax
    $ServerCpu = "$scpu"
    $AgentCpu = "$acpu"

    $ServerMemory = Read-SizeValue -Prompt "Server RAM" -Default $defServerMem  -Kind Memory
    $AgentMemory = Read-SizeValue -Prompt "Worker RAM" -Default $defAgentMem   -Kind Memory
    $ServerDisk = Read-SizeValue -Prompt "Server disk" -Default $defServerDisk -Kind Disk
    $AgentDisk = Read-SizeValue -Prompt "Worker disk" -Default $defAgentDisk  -Kind Disk

    $defaultImg = if ([string]::IsNullOrWhiteSpace($Image)) { "" } else { $Image }
    $Image = Select-UbuntuImageInteractive -MultipassCmd $MultipassCmd -DefaultImage $defaultImg

    $knownChannels = Get-K3sChannelList
    $defaultCh = if ([string]::IsNullOrWhiteSpace($Channel)) { "stable" } else { $Channel }
    $Channel = Select-ChannelInteractive -Known $knownChannels -DefaultChannel $defaultCh

    $useAdvanced = Read-YesNo -Prompt "Advanced options?" -Default $false

    $outDirDefault = if ([string]::IsNullOrWhiteSpace($OutputDir)) { Join-Path (Get-ClustersRoot) $cluster } else { $OutputDir }
    if ($useAdvanced) {
        while ($true) {
            $outAns = Read-Host "Output directory [$outDirDefault]"
            $candidate = if ([string]::IsNullOrWhiteSpace($outAns)) { $outDirDefault } else { $outAns.Trim() }
            try {
                $OutputDir = Resolve-OutputDirectory -PathLike $candidate
                break
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Yellow
            }
        }
    }
    else {
        $OutputDir = Resolve-OutputDirectory -PathLike $outDirDefault
    }

    $DisableFlannel = Read-YesNo -Prompt "Flannel off?" -Default ([bool]$DisableFlannel)

    $defaultProfile = 1
    if ($Minimal) { $defaultProfile = 2 }
    elseif ($DisableTraefik -or $DisableServiceLB -or $DisableMetricsServer) { $defaultProfile = 3 }

    Write-Host ""
    Write-Host "Addons profile" -ForegroundColor DarkCyan
    Write-Host "  1. default (Traefik + ServiceLB + metrics-server)"
    Write-Host "  2. minimal (disable all three)"
    Write-Host "  3. custom"

    $profileChoice = Read-IntInRange -Prompt "Select" -Default $defaultProfile -Min 1 -Max 3

    switch ($profileChoice) {
        1 {
            $Minimal = $false
            $DisableTraefik = $false
            $DisableServiceLB = $false
            $DisableMetricsServer = $false
        }
        2 {
            $Minimal = $true
            $DisableTraefik = $true
            $DisableServiceLB = $true
            $DisableMetricsServer = $true
        }
        3 {
            $Minimal = $false
            $DisableTraefik = Read-YesNo -Prompt "Traefik off?"        -Default ([bool]$DisableTraefik)
            $DisableServiceLB = Read-YesNo -Prompt "ServiceLB off?"      -Default ([bool]$DisableServiceLB)
            $DisableMetricsServer = Read-YesNo -Prompt "metrics-server off?" -Default ([bool]$DisableMetricsServer)
        }
    }

    $KeepCloudInit = Read-YesNo -Prompt "Keep cloud-init YAML files?" -Default ([bool]$KeepCloudInit)
    if ($KeepCloudInit) {
        Write-Warning "Cloud-init YAML contains tokens."
    }

    if ($NoKubeconfig) {
        $SaveKubeconfig = $false
        $KubeconfigName = ""
        $MergeKubeconfig = $false
        $MergedKubeconfigName = ""
    }
    else {
        $SaveKubeconfig = $true
        if (-not $MergeKubeconfig) {
            $MergedKubeconfigName = ""
        }
    }

    Write-Host ""
    $versionLabel = if ([string]::IsNullOrWhiteSpace($K3sVersion)) { '' } else { " ($K3sVersion)" }
    $srvTotal = ($ServerCount + 1)
    $wkrTotal = $AgentCount

    $labelWidth = 11

    Write-Host "Review" -ForegroundColor Green
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'cluster', $cluster)
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'servers', $srvTotal)
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'workers', $wkrTotal)
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'image', $Image)
    Write-Host ("  {0,-$labelWidth}: {1}{2}" -f 'k3s', $Channel, $versionLabel)

    $cniLabel = if ($DisableFlannel) { 'none' } else { 'flannel' }
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'cni', $cniLabel)

    $addonNames = @()
    if (-not $Minimal) {
        if (-not $DisableTraefik) { $addonNames += 'traefik' }
        if (-not $DisableServiceLB) { $addonNames += 'servicelb' }
        if (-not $DisableMetricsServer) { $addonNames += 'metrics' }
    }
    $addonsLabel = if ($addonNames.Count -gt 0) { $addonNames -join ', ' } else { 'none' }
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'addons', $addonsLabel)

    Write-Host ("  {0,-$labelWidth}: {1}cpu/{2}/{3}" -f 'server size', $ServerCpu, $ServerMemory, $ServerDisk)
    Write-Host ("  {0,-$labelWidth}: {1}cpu/{2}/{3}" -f 'worker size', $AgentCpu, $AgentMemory, $AgentDisk)

    if ($useAdvanced) {
        $saveKubeconfigLabel = if ($SaveKubeconfig) { 'yes' } else { 'no' }
        $mergeLabel = if ($MergeKubeconfig) { 'yes' } else { 'no' }
        Write-Host ("  {0,-$labelWidth}: kubeconfig={1}  merged={2}" -f 'files', $saveKubeconfigLabel, $mergeLabel)
        Write-Host ("  {0,-$labelWidth}: {1}" -f 'out', $OutputDir)
    }

    $cloudInitLabel = if ($KeepCloudInit) { 'keep' } else { 'delete' }
    Write-Host ("  {0,-$labelWidth}: {1}" -f 'cloud-init', $cloudInitLabel)

    try {
        Show-HostResourceEstimate -ServerCount $ServerCount -AgentCount $AgentCount -ServerMemory $ServerMemory -AgentMemory $AgentMemory
    }
    catch {

    }

    if (-not (Read-YesNo -Prompt "Proceed?" -Default $true)) {
        Write-Host "Cluster creation cancelled." -ForegroundColor Yellow
        return [pscustomobject]@{ Proceed = $false }
    }

    return [pscustomobject]@{
        Proceed                    = $true
        ClusterName                = $cluster
        Channel                    = $Channel
        K3sVersion                 = $K3sVersion
        Image                      = $Image
        ServerCount                = $ServerCount
        AgentCount                 = $AgentCount
        ServerCpu                  = $ServerCpu
        AgentCpu                   = $AgentCpu
        ServerDisk                 = $ServerDisk
        AgentDisk                  = $AgentDisk
        ServerMemory               = $ServerMemory
        AgentMemory                = $AgentMemory
        DisableFlannel             = [bool]$DisableFlannel

        SaveKubeconfig             = [bool]$SaveKubeconfig
        NoKubeconfig               = [bool]$NoKubeconfig
        MergeKubeconfig            = [bool]$MergeKubeconfig
        KubeconfigName             = $KubeconfigName
        MergedKubeconfigName       = $MergedKubeconfigName
        OutputDir                  = $OutputDir
        KeepCloudInit              = [bool]$KeepCloudInit

        LaunchTimeoutSeconds       = $LaunchTimeoutSeconds
        Minimal                    = [bool]$Minimal
        RemoteCmdTimeoutSeconds    = $RemoteCmdTimeoutSeconds
        ApiReadyTimeoutSeconds     = $ApiReadyTimeoutSeconds
        NodeRegisterTimeoutSeconds = $NodeRegisterTimeoutSeconds
        NodeReadyTimeoutSeconds    = $NodeReadyTimeoutSeconds
        DisableTraefik             = [bool]$DisableTraefik
        DisableServiceLB           = [bool]$DisableServiceLB
        DisableMetricsServer       = [bool]$DisableMetricsServer
    }
}
