$script:CancelRequested = $false
$script:CancelHintShown = $false
$script:MultipassWaitReadyUnsupported = $false
$script:MultipassWaitReadyWarned = $false
$global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $false

Set-Variable -Scope Script -Name ScriptName -Value 'k3s-cluster-setup.ps1'
