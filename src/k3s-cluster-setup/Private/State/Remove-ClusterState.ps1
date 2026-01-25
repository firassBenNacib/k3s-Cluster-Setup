function Remove-ClusterState([string]$name) {
    Use-StateFileLock -ScriptBlock {
        $state = Get-StateUnlocked
        if ($state.clusters -and ($state.clusters -is [hashtable]) -and $state.clusters.ContainsKey($name)) {
            [void]$state.clusters.Remove($name)
            Set-StateUnlocked $state
        }
    }
}
