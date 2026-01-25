function ConvertTo-BashSingleQuoted {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) {
        $Value = ""
    }
    $escaped = $Value -replace "'", "'`"`'`"`'"
    return ("'" + $escaped + "'")
}
