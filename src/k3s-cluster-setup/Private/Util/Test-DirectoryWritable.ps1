function Test-DirectoryWritable {
    param([Parameter(Mandatory)][string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        $probe = Join-Path $Path ([System.IO.Path]::GetRandomFileName())
        "probe" | Set-Content -Path $probe -Encoding ASCII -ErrorAction Stop
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}
