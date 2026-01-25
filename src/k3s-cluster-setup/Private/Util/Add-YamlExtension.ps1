function Add-YamlExtension {
    param([string]$PathLike)
    if ([string]::IsNullOrWhiteSpace($PathLike)) {
        return $PathLike
    }
    if ($PathLike -match '\.(yml|yaml)$') {
        return $PathLike
    }

    $dir = Split-Path -Parent $PathLike
    $leaf = Split-Path -Leaf   $PathLike
    $base = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
    $newLeaf = "$base.yaml"
    if ([string]::IsNullOrWhiteSpace($dir)) {
        return $newLeaf
    }
    return (Join-Path $dir $newLeaf)
}
