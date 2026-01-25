function New-RandomString {
    param([int]$Length = 6)
    $chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    if ($Length -le 0) {
        return ""
    }
    $bytes = New-Object byte[] ($Length)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }
    $sb = New-Object System.Text.StringBuilder
    $max = $chars.Length
    foreach ($b in $bytes) {
        [void]$sb.Append($chars[$b % $max])
    }
    return $sb.ToString()
}
