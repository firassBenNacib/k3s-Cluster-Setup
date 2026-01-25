function New-UniqueClusterName {
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [int]$Length = 6,
        [int]$MaxAttempts = 50
    )
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        $cand = New-RandomString -Length $Length
        if (-not (Test-ClusterExists -MultipassCmd $MultipassCmd -ClusterName $cand)) {
            return $cand
        }
    }
    throw "Unable to generate a unique cluster name after $MaxAttempts attempts."
}
