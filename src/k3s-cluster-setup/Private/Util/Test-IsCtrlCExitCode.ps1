function Test-IsCtrlCExitCode {
    param([int]$Code)

    $u = [uint32]$Code

    if ($u -eq 130) { return $true }
    if ($u -eq 0xC000013A) { return $true }
    return $false
}
