function Get-MultipassCmd {
    if (Get-Command multipass.exe -ErrorAction SilentlyContinue) {
        return "multipass.exe"
    }
    if (Get-Command multipass -ErrorAction SilentlyContinue) {
        return "multipass"
    }
    throw "Multipass is not available. Please install Multipass first."
}
