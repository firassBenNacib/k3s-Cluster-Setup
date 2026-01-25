function Get-HostMemoryInfo {

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        if ($null -eq $os) { return $null }

        $freeBytes = [int64]$os.FreePhysicalMemory * 1024
        $totalBytes = [int64]$os.TotalVisibleMemorySize * 1024

        return [pscustomobject]@{
            FreeBytes  = $freeBytes
            TotalBytes = $totalBytes
        }
    }
    catch {
        return $null
    }
}
