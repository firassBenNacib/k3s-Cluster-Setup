function Resolve-KubeconfigList {
    param([string]$KubeEnv)
    $paths = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($KubeEnv)) {
        return @()
    }
    $sep = [System.IO.Path]::PathSeparator
    foreach ($p in ($KubeEnv -split [regex]::Escape($sep))) {
        $pp = Expand-UserPath ($p.Trim())
        if ([string]::IsNullOrWhiteSpace($pp)) {
            continue
        }
        if (Test-Path -LiteralPath $pp) {
            [void]$paths.Add((Resolve-Path -LiteralPath $pp).Path)
        }
    }
    return @($paths)
}
