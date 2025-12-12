# Getting input from user if not running from RMM else set variables from RMM.

$scriptLogName = "n-able-uninstall.log"

if ($rmm -ne 1) {
    $validInput = 0
    # Checking for valid input.
    while ($validInput -ne 1) {
        # Ask for input here. This is the interactive area for getting variable information.
        # Remember to make validInput = 1 whenever correct input is given.
        $description = Read-Host "Please enter the ticket # and, or your initials. Its used as the description for the job"
        if ($description) {
            $validInput = 1
        } else {
            Write-Output "Invalid input. Please try again."
        }
    }
    $logPath = "$env:WINDIR\logs\$scriptLogName"

} else { 
    # Store the logs in the rmmScriptPath
    $logPath = "$rmmScriptPath\logs\$scriptLogName"

    if ($description -eq $null) {
        Write-Host "Description is null. This was most likely run automatically from the RMM and no information was passed."
        $description = "No description"
    }   

    Write-Output $description
    Write-Output $rmmScriptPath
    Write-Output $rmm
    
}

Start-Transcript -Path $logPath

# Define service names
$ServiceNames = @("MspAgent", "Windows Agent Service")

# Find the first service that exists
$Service = $null
foreach ($name in $ServiceNames) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        $Service = $svc
        $ServiceName = $name
        break
    }
}

if ($Service) {
    Write-Output "Found service: $($Service.Name)"
    try {
        # Check if N-able software is installed by publisher
        $installed = Get-WmiObject -Class Win32_Product | Where-Object { 
            $_.Vendor -like "*N-able*" 
        }
        
        if ($installed) {
            Write-Output "N-able software found. Uninstalling..."
            $installed | ForEach-Object {
                try {
                    Write-Output "Uninstalling: $($_.Name)"
                    $_.Uninstall()
                    Start-Sleep -Seconds 10
                } catch {
                    Write-Output "An error occurred during uninstall: $_"
                }    
            }
        }
        
        # Check if application is still installed
        $installCheck = Get-WmiObject -Class Win32_Product | Where-Object { 
            $_.Vendor -like "*N-able*" 
        }
        
        if ($installCheck) {
            Write-Output "Software uninstall failed. Attempting service force deletion..."
            
            # Stop the service
            $Service | Stop-Service -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Delete the service using sc.exe
            $ServiceDeleteResult = & sc.exe delete $ServiceName 2>&1
            Write-Output "Service delete output: $ServiceDeleteResult"
            
            Start-Sleep -Seconds 2
            
            # Verify service is deleted
            $IsServiceDeleted = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            
            if (-not $IsServiceDeleted) {
                Write-Output "Service $ServiceName forcibly deleted successfully."
                Exit 0
            } else {
                Write-Output "Service $ServiceName still exists. Delete failed."
                Exit 1
            }
        } else {
            Write-Output "N-able software uninstalled successfully."
            Exit 0
        }
    } catch {
        Write-Output "Error occurred while processing $($Service.Name): $_"
        Exit 1
    }
} else {
    Write-Output "Service $ServiceName not found."
    Exit 0
}

Stop-Transcript
