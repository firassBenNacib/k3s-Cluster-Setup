function Set-ClusterState {
    [CmdletBinding(PositionalBinding = $true)]
    param(

        [Parameter(Mandatory, Position = 0)]
        [Alias('ClusterName')]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [Alias('ClusterEntry')]
        $Entry
    )

    Use-StateFileLock -ScriptBlock {
        $state = Get-StateUnlocked
        if (-not $state.clusters) {
            $state.clusters = @{}
        }
        if ($state.clusters -isnot [hashtable]) {
            $tmp = @{}
            foreach ($p in $state.clusters.PSObject.Properties) {
                $tmp[$p.Name] = $p.Value
            }
            $state.clusters = $tmp
        }
        $state.clusters[$Name] = $Entry
        Set-StateUnlocked $state
    }
}
