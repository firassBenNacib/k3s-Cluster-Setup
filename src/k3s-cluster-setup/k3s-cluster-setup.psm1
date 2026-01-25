Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$script:ModuleRoot = $PSScriptRoot

$Public = Join-Path $PSScriptRoot "Public"
$Private = Join-Path $PSScriptRoot "Private"

$init = Join-Path $Private "Init.ps1"
$globals = Join-Path $Private "Globals.ps1"

if (Test-Path -LiteralPath $init) {
    . $init
}

Get-ChildItem -Path $Private -Filter "*.ps1" -File -Recurse |
    Where-Object { $_.FullName -ne $init -and $_.FullName -ne $globals } |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

if (Test-Path -LiteralPath $globals) {
    . $globals
}

Get-ChildItem -Path $Public -Filter "*.ps1" -File -Recurse |
    Sort-Object FullName |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    "Invoke-K3sClusterSetup",
    "New-K3sCluster",
    "Get-K3sClusters",
    "Remove-K3sCluster",
    "Remove-K3sNode",
    "Remove-AllK3sClusters",
    "Use-K3sClusterContext"
)
