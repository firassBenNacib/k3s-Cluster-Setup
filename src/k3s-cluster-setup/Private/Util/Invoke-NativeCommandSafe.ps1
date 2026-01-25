function Invoke-NativeCommandSafe {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$CommandArgs
    )

    $oldEap = $ErrorActionPreference
    $hasNativePref = $false
    $oldNativePref = $null
    try {
        $prefVar = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
        if ($null -ne $prefVar) {
            $hasNativePref = $true
            $oldNativePref = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }
    }
    catch {
        Write-NonFatalError $_
    }

    $ErrorActionPreference = "Continue"
    $out = $null
    $code = 0
    try {
        $out = & $FilePath @CommandArgs 2>&1
        $code = $LASTEXITCODE
    }
    catch {
        $out = $_.Exception.Message
        $code = 1
    }
    finally {
        $ErrorActionPreference = $oldEap
        if ($hasNativePref) {
            $PSNativeCommandUseErrorActionPreference = $oldNativePref
        }
    }

    return [pscustomobject]@{
        ExitCode = $code
        Output   = ($out | Out-String)
    }
}
