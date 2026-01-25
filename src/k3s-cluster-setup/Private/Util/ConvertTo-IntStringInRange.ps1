function ConvertTo-IntStringInRange {
    param([string]$Raw, [int]$Min, [int]$Max, [string]$Name)
    $v = 0
    if (-not [int]::TryParse($Raw, [ref]$v)) {
        throw "$Name must be a number (got '$Raw')."
    }
    if ($v -lt $Min -or $v -gt $Max) {
        throw "$Name must be between $Min and $Max (got $v)."
    }
    return $v.ToString()
}
