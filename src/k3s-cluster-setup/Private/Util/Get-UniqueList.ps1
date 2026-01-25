function Get-UniqueList {
    param([object[]]$Items)
    $src = @($Items)
    $src = @($src | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace($_.ToString()) })
    return @(@($src) | Sort-Object -Unique)
}
