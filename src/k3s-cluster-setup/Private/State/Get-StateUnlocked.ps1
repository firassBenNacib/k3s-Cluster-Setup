function Get-StateUnlocked {
    if (Test-Path -LiteralPath $StatePath) {
        try {
            $s = (Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json)
            if (-not $s) {
                return [pscustomobject]@{ clusters = @{} }
            }
            if (-not (Test-HasProperty -Object $s -Name "clusters") -or -not $s.clusters) {
                $s | Add-Member -NotePropertyName clusters -NotePropertyValue @{} -Force
            }
            else {
                if ($s.clusters -isnot [hashtable]) {
                    $ht = @{}
                    foreach ($p in $s.clusters.PSObject.Properties) {
                        $ht[$p.Name] = $p.Value
                    }
                    $s.clusters = $ht
                }
            }

            if (-not (Test-HasProperty -Object $s -Name "meta") -or -not $s.meta) {
                $s | Add-Member -NotePropertyName meta -NotePropertyValue ([pscustomobject]@{}) -Force
            }
            return $s
        }
        catch {
            Write-Verbose ("Failed to read/parse state file '{0}': {1}" -f $StatePath, $_.Exception.Message)
            return [pscustomobject]@{ clusters = @{}; meta = ([pscustomobject]@{}) }
        }
    }
    return [pscustomobject]@{ clusters = @{}; meta = ([pscustomobject]@{}) }
}
