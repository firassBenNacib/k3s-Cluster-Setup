function Get-NewServerName([string]$cluster, [int]$index) { return ("k3s-srv{0}-{1}" -f $index, $cluster) }
