@{
    RootModule        = 'k3s-cluster-setup.psm1'
    ModuleVersion     = '1.0.0'
    Author            = 'Firas Ben Nacib'
    CompanyName       = 'Firas Ben Nacib'
    Copyright         = '(c) 2026 Firas Ben Nacib. MIT License.'
    Description       = 'k3s cluster manager for Multipass on Windows.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Invoke-K3sClusterSetup',
        'New-K3sCluster',
        'Get-K3sClusters',
        'Remove-K3sCluster',
        'Remove-K3sNode',
        'Remove-AllK3sClusters',
        'Use-K3sClusterContext'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('k3s','kubernetes','multipass','devops','powershell')
            LicenseUri   = 'https://github.com/firassBenNacib/k3s-Cluster-Setup/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/firassBenNacib/k3s-Cluster-Setup'
            Repository   = 'https://github.com/firassBenNacib/k3s-Cluster-Setup'
            License      = 'MIT'
        }
    }
}
