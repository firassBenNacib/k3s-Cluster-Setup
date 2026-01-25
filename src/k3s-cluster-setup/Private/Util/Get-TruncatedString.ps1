function Get-TruncatedString {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [string]$Value,

        [Parameter(Mandatory, Position = 1)]
        [int]$Width
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    if ($Width -le 0) { return '' }
    if ($Value.Length -le $Width) { return $Value }
    if ($Width -le 3) { return $Value.Substring(0, $Width) }
    return ($Value.Substring(0, $Width - 3) + '...')
}
