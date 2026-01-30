function Get-NewAgentName([string]$cluster, [int]$index) { return ("k3s-agt{0}-{1}" -f $index, $cluster) }
