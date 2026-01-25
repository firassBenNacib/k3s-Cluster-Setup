function Stop-IfCancelled {

    $helperCancel = $false
    try {
        if (([System.Management.Automation.PSTypeName]'K3sClusterSetupCancelHelper').Type) {
            $helperCancel = [bool]([K3sClusterSetupCancelHelper]::CancelRequested)
        }
    }
    catch { }

    if ($helperCancel) {
        $script:CancelRequested = $true
        $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $true
    }

    if ($script:CancelRequested -or $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED -or $helperCancel) {
        throw [System.OperationCanceledException]::new("Cancelled by user.")
    }
}
