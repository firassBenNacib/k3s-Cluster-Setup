function Get-State {
    Use-StateFileLock -ScriptBlock {
        Get-StateUnlocked
    }
}
