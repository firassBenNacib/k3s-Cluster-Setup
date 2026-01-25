[CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('create', 'interactive', 'delete', 'deletenode', 'stop', 'start', 'list', 'listall', 'usecontext', 'help')]
    [string]$Command = 'help',

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$ClusterName = "",

    [Parameter(Mandatory = $false)]
    [string[]]$Clusters = @(),

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$NodeName = "",

    [Parameter(Mandatory = $false)]
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [switch]$NoKubeconfig,

    [Parameter(Mandatory = $false)]
    [switch]$MergeKubeconfig,

    [Parameter(Mandatory = $false)]
    [string]$KubeconfigName = "",

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "",

    [Parameter(Mandatory = $false)]
    [switch]$KeepCloudInit,

    [Parameter(Mandatory = $false)]
    [string]$MergedKubeconfigName = "",

    [Parameter(Mandatory = $false)]
    [switch]$PurgeFiles,

    [Parameter(Mandatory = $false)]
    [switch]$PurgeMultipass,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$All,

    [Parameter(Mandatory = $false)]
    [string]$Image = "",

    [Parameter(Mandatory = $false)]
    [int]$ServerCount = -1,

    [Parameter(Mandatory = $false)]
    [int]$AgentCount = -1,

    [Parameter(Mandatory = $false)]
    [string]$ServerCpu = "",

    [Parameter(Mandatory = $false)]
    [string]$AgentCpu = "",

    [Parameter(Mandatory = $false)]
    [string]$ServerDisk = "",

    [Parameter(Mandatory = $false)]
    [string]$AgentDisk = "",

    [Parameter(Mandatory = $false)]
    [string]$ServerMemory = "",

    [Parameter(Mandatory = $false)]
    [string]$AgentMemory = "",

    [Parameter(Mandatory = $false)]
    [string]$Channel = "stable",

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$K3sVersion = "",

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$ServerToken = "",

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$AgentToken = "",

    [Parameter(Mandatory = $false)]
    [switch]$DisableFlannel,

    [Parameter(Mandatory = $false)]
    [switch]$Minimal,

    [Parameter(Mandatory = $false)]
    [switch]$DisableTraefik,

    [Parameter(Mandatory = $false)]
    [switch]$DisableServiceLB,

    [Parameter(Mandatory = $false)]
    [switch]$DisableMetricsServer,

    [Parameter(Mandatory = $false)]
    [int]$LaunchTimeoutSeconds = 900,

    [Parameter(Mandatory = $false)]
    [int]$RemoteCmdTimeoutSeconds = 20,

    [Parameter(Mandatory = $false)]
    [int]$ApiReadyTimeoutSeconds = 900,

    [Parameter(Mandatory = $false)]
    [int]$NodeRegisterTimeoutSeconds = 900,

    [Parameter(Mandatory = $false)]
    [int]$NodeReadyTimeoutSeconds = 1800,

    [Parameter(Mandatory = $false)]
    [switch]$ExitOnFinish
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here ".." )).Path

if ([string]::IsNullOrWhiteSpace($env:K3S_CLUSTER_SETUP_ARTIFACTS_ROOT) -and [string]::IsNullOrWhiteSpace($OutputDir)) {
    $env:K3S_CLUSTER_SETUP_ARTIFACTS_ROOT = $repoRoot
}

$module = Join-Path $here "..\src\k3s-cluster-setup\k3s-cluster-setup.psd1"
Import-Module (Resolve-Path $module).Path -Force

$__cancelHandler = $null

try {
    if (-not ([System.Management.Automation.PSTypeName]'K3sClusterSetupCancelHelper').Type) {
        Add-Type -Language CSharp -ErrorAction Stop -TypeDefinition @"
using System;

public static class K3sClusterSetupCancelHelper
{
    public static volatile bool CancelRequested = false;

    public static void Reset()
    {
        CancelRequested = false;
    }

    public static void Handler(object sender, ConsoleCancelEventArgs e)
    {
        CancelRequested = true;
        try { e.Cancel = true; } catch { }
        try {
            Console.Error.WriteLine();
            Console.Error.WriteLine("Cancel requested. Cleaning up...");
        } catch { }
    }
}
"@
    }
}
catch {

}

try { [K3sClusterSetupCancelHelper]::Reset() } catch { }
$global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $false

try {
    $__cancelHandler = [ConsoleCancelEventHandler][K3sClusterSetupCancelHelper]::Handler
    [Console]::add_CancelKeyPress($__cancelHandler)
}
catch {
    $__cancelHandler = $null
}

try {
    $uiName = Split-Path -Leaf $MyInvocation.MyCommand.Path
    $bp = @{} + $PSBoundParameters
    $null = $bp.Remove("ExitOnFinish")
    Invoke-K3sClusterSetup @bp -UiScriptName $uiName

    $global:LASTEXITCODE = 0
}
catch [System.Management.Automation.PipelineStoppedException] {
    if ($global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED) {
        Write-Warning "Cancelled (Ctrl+C)."
    }
    $global:LASTEXITCODE = 130
}
catch [System.OperationCanceledException] {
    if ($global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED) {
        Write-Warning "Cancelled."
    }
    $global:LASTEXITCODE = 130
}
catch {

    try {
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }
    catch {
        Write-Error $_ -ErrorAction Continue
    }
    $global:LASTEXITCODE = 1
}
finally {
    try {
        if ($__cancelHandler) { [Console]::remove_CancelKeyPress($__cancelHandler) }
    }
    catch { }
    $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $false
    try { [K3sClusterSetupCancelHelper]::Reset() } catch { }
}

if ($ExitOnFinish) {
    $exitCode = $global:LASTEXITCODE
    exit $exitCode
}
return
