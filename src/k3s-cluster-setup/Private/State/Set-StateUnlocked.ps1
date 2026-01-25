function Set-StateUnlocked($state) {
    $dir = Split-Path -Parent $StatePath
    if ([string]::IsNullOrWhiteSpace($dir)) {
        $dir = "."
    }
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tmp = Join-Path $dir ([System.IO.Path]::GetRandomFileName())
    $json = $state | ConvertTo-Json -Depth 12
    $enc = if ($PSVersionTable.PSVersion.Major -ge 6) { "utf8NoBOM" } else { "utf8" }

    $json | Set-Content -Path $tmp -Encoding $enc -ErrorAction Stop
    Move-Item -Path $tmp -Destination $StatePath -Force
}
