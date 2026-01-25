function ConvertTo-Array {
    param([AllowNull()]$Value)
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [string]) {
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value)
    }
    return @($Value)
}
