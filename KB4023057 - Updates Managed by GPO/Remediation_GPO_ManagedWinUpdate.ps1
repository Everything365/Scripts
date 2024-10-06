# Define the registry paths
$gpoRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$mdmRegistryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy"

try {
    # Check and remove Group Policy registry key (if it exists)
    if (Test-Path $gpoRegistryPath) {
        Remove-Item -Path $gpoRegistryPath -Recurse -Force
        Write-Output "Group Policy registry key deleted."
    } else {
        Write-Output "Group Policy registry key does not exist, no action taken."
    }

    # Check and remove MDM Update Policy registry key (if it exists)
    if (Test-Path $mdmRegistryPath) {
        Remove-Item -Path $mdmRegistryPath -Recurse -Force
        Write-Output "MDM Update Policy registry key deleted."
    } else {
        Write-Output "MDM Update Policy registry key does not exist, no action taken."
    }

    # Start MDM Sync after registry keys are removed
    try {
        [Windows.Management.MdmSessionManager, Windows.Management, ContentType = WindowsRuntime]
        $session = [Windows.Management.MdmSessionManager]::TryCreateSession()
        $session.StartAsync() | Out-Null
        Write-Output "MDM sync initiated."
    }
    catch {
        Write-Output "Failed to initiate MDM sync: $($_.Exception.Message)"
    }

    # Exit with 0 to indicate successful remediation
    exit 0
}
catch {
    # If an error occurs, output the error message and exit with 1 to indicate failure
    Write-Output "Failed to delete the registry key(s): $($_.Exception.Message)"
    exit 1
}
