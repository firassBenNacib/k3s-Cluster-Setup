function Remove-K3sClusterCloudInitFiles {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedFiles
    )

    try {
        $ciFiles = @($CreatedFiles | Where-Object { $_ -and ($_ -match '-cloud-init\.ya?ml$') })
        foreach ($f in @($ciFiles)) {
            try {
                if ($f -and (Test-Path -LiteralPath $f)) {
                    Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }
        if ($ciFiles.Count -gt 0) {
            Write-Verbose ("Removed {0} cloud-init file(s). Use -KeepCloudInit to retain them for debugging." -f $ciFiles.Count)
        }
    }
    catch {
        Write-NonFatalError $_
    }
}
