$script:CancelRequested = $false
$script:CancelHintShown = $false
$script:MultipassWaitReadyUnsupported = $false
$script:MultipassWaitReadyWarned = $false

Set-Variable -Scope Script -Name ScriptName -Value 'k3s-cluster-setup.ps1'
