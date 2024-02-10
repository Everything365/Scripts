<#
.SYNOPSIS
This script imports a configured taskbar and copies any required .lnk files to the AppData folder.
Version 1, single run during deployment for first user.

.DESCRIPTION
The script works by performing the following steps:
1. Imports shortcut files for new taskbar.
2. Imports registry values for taskbar icons.
3. Checks if any error occured and writes results to registry.
4. Log created in Windows\temp
#>

# If running in a 64-bit process, relaunch as 32-bit
If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

# CleanUpAndExit
Function CleanUpAndExit() {
    Param(
        [Parameter()][int]$ErrorLevel = 0
    )
	
    # Write results to registry for Intune Detection
	$StoreResults = "\Contoso\Taskbar" # Change this to something that fits you.
    $Key = "HKEY_LOCAL_MACHINE\Software$StoreResults"
    $NOW = Get-Date -Format "yyyyMMdd-HHmmss"

    If ($ErrorLevel -eq 0) {
        [Microsoft.Win32.Registry]::SetValue($Key, "Success", $NOW)
    } else {
        [Microsoft.Win32.Registry]::SetValue($Key, "Failure", $NOW)
        [Microsoft.Win32.Registry]::SetValue($Key, "Error Code", $Errorlevel)
    }
    
    # Exit Script with the specified ErrorLevel
    EXIT $ErrorLevel
}

# Log File Info
$Now = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = "$ENV:WINDIR\Temp\ImportTaskbar_$Now.log"

# Function to write log entries
function Write-LogEntry {
    param(
        [string]$Message
    )
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File -FilePath $LogPath -Append
}

# Write to log file
Write-LogEntry "Start Setting Taskbar"

# Copy-TaskbarFilesToAllUsers
function Copy-TaskbarFilesToAllUsers {
    param(
        [string]$sourceDir = "$PSScriptRoot\AppData"
    )
	
	Write-LogEntry "Copying taskbar files for all users..."

    $Success = $true

    $userSIDs = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false } | ForEach-Object { $_.SID }

    foreach ($userSID in $userSIDs) {
        $userProfilePath = (New-Object System.Management.ManagementObject "Win32_UserProfile.SID='$userSID'").LocalPath

        try {
            # Define target directory for the current user
            $targetDir = "$userProfilePath\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

            # Ensure the target directory exists
            if (!(Test-Path -Path $targetDir)) {
                New-Item -ItemType Directory -Force -Path $targetDir
            }

            # Copy files from source to target
            Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force
			Write-LogEntry "Files copied successfully for user $userSID."
        }
        catch {
			$ErrorMessage = "An error occurred while copying files for user ${userSID}: $($_.Exception.Message)"
			Write-LogEntry $ErrorMessage
			Write-Host $ErrorMessage -ForegroundColor Red
            $Success = $false
        }
    }

    if ($Success) {
        Write-LogEntry "Files are copied successfully for all users."
    }
    return $Success
}

# Import-RegFileToAllUsers
function Import-RegFileToAllUsers {
	
	Write-LogEntry "Importing registry values for all users..."
    $Success = $false
	$originalRegFileContent = Get-Content -Path "$PSScriptRoot\Taskbar.reg"

    foreach ($userPath in (Get-ChildItem "Registry::HKEY_USERS\" | Where-Object { $_.Name -notmatch '_Classes|S-1-5-18|S-1-5-19|S-1-5-20|\.Default' })) {
        $username = $userPath.PSChildName

        try {
            # Replace the specific user SID with the SID of the current user in the loop
            $modifiedRegFileContent = $originalRegFileContent -replace 'UserSID', $username

            # Write the modified content to a temporary .reg file
            $tempRegFilePath = Join-Path -Path $PSScriptRoot -ChildPath "TempTaskBar.reg"
            $modifiedRegFileContent | Out-File -FilePath $tempRegFilePath

            # Import the temporary .reg file
            Start-Process -FilePath "regedit.exe" -ArgumentList "/s `"$tempRegFilePath`"" -NoNewWindow -Wait

            # Delete the temporary .reg file
            Remove-Item -Path $tempRegFilePath -Force

            $Success = $true
			Write-LogEntry "Registry values imported successfully for user $username."
        }
        catch {
            $ErrorMessage = "An error occurred while importing registry values for user ${username}: $($_.Exception.Message)"
			Write-LogEntry $ErrorMessage
			Write-Host $ErrorMessage -ForegroundColor Red
            $Success = $false
            return $Success
        }
    }

    if ($Success) {
        Write-Host "Registry values are set correctly for all users."
    }
    return $Success
}

# Call the Copy-TaskbarFilesToAllUsers function
$importAppDataResult = Copy-TaskbarFilesToAllUsers

# Call the Import-RegFileToAllUsers function
$importRegFileResult = Import-RegFileToAllUsers

# If all functions ran successfully, exit with error code 0, else use error code 101
if ($importAppDataResult -and $importRegFileResult) {
    Write-LogEntry "All functions completed successfully. Cleaning up and exiting..."
	CleanUpAndExit -ErrorLevel 0
} else {
    Write-LogEntry "One or more functions encountered errors. Cleaning up and exiting..."
	CleanUpAndExit -ErrorLevel 101
}

Write-LogEntry "Script execution completed."
$LogPath = $null