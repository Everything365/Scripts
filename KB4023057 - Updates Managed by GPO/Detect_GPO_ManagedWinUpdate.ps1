# Define the registry paths and value
$gpoRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$mdmRegistryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState"
$keyName = "FeatureUpdatePausePeriodInDays"
$expectedValue = 23

# Check if the Group Policy registry key exists
if (Test-Path $gpoRegistryPath) {
    Write-Output "Registry key exists."

    # Optional: Uncomment the following block if you want to check for FeatureUpdatePausePeriodInDays
    # if (Test-Path $mdmRegistryPath) {
    #     $value = Get-ItemProperty -Path $mdmRegistryPath -Name $keyName -ErrorAction SilentlyContinue
    #     if ($value.$keyName -eq $expectedValue) {
    #         Write-Output "FeatureUpdatePausePeriodInDays is 23."
    #         exit 0
    #     } else {
    #         Write-Output "FeatureUpdatePausePeriodInDays is not 23."
    #         exit 1
    #     }
    # }

    exit 0
}
else {
    Write-Output "Registry key does not exist."
    exit 1
}
