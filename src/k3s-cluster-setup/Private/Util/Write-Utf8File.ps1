function Write-Utf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-SafeDirectory -Path $dir
    }

    $text = if ($Content -is [System.Array]) {
        [string]::Join([Environment]::NewLine, $Content)
    }
    else {
        [string]$Content
    }

    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $text, $enc)
}
