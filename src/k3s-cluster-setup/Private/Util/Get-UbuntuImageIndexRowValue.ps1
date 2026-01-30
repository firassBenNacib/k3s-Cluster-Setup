function Get-UbuntuImageIndexRowValue {
    param([Parameter(Mandatory)]$Row, [Parameter(Mandatory)][string]$Name)

    if ($null -eq $Row) {
        return $null
    }
    if (Test-HasProperty -Object $Row -Name $Name) {
        return $Row.$Name
    }
    return $null
}
