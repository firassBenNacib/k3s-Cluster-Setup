function Enable-CancelHandler {
    param([ref]$Handler)
    $script:CancelRequested = $false
    $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $false
    $script:CancelHintShown = $false

    try {
        if (-not ([System.Management.Automation.PSTypeName]'K3sClusterSetupCancelHelper').Type) {
            Add-Type -Language CSharp -ErrorAction Stop -TypeDefinition @"
using System;

public static class K3sClusterSetupCancelHelper
{
    public static volatile bool CancelRequested = false;

    public static void Reset()
    {
        CancelRequested = false;
    }

    public static void Handler(object sender, ConsoleCancelEventArgs e)
    {
        CancelRequested = true;
        try { e.Cancel = true; } catch { }
        try {
            Console.Error.WriteLine();
            Console.Error.WriteLine("Cancel requested. Cleaning up...");
        } catch { }
    }
}
"@
        }
    }
    catch {

    }

    try { [K3sClusterSetupCancelHelper]::Reset() } catch { }

    $h = $null
    try {
        $h = [ConsoleCancelEventHandler][K3sClusterSetupCancelHelper]::Handler
        [Console]::add_CancelKeyPress($h)
        $Handler.Value = $h
    }
    catch {
        $Handler.Value = $null
    }
}
