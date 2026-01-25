function Test-HasProperty {
    param([AllowNull()]$Object, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Object) {
        return $false
    }
    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }
    $props = $Object.PSObject.Properties
    if ($null -eq $props) {
        return $false
    }
    return ($null -ne $props[$Name])
}
