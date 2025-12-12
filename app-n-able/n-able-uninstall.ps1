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

# Define service names to check
$ServiceNames = @("MspAgent", "Windows Agent Service")

# Track if any services were found
$ServiceFound = $false
$ServicesToProcess = @()

# Check for all services
foreach ($ServiceName in $ServiceNames) {
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($Service) {
        Write-Output "Found service: $($Service.Name)"
        $ServiceFound = $true
        $ServicesToProcess += $Service
    } else {
        Write-Output "Service $ServiceName not found."
    }
}

if ($ServiceFound) {
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
            
            # Stop all services
            $ServicesToProcess | ForEach-Object {
                $_.Stop-Service -Force -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds 2
            
            # Delete each service using sc.exe
            foreach ($Service in $ServicesToProcess) {
                $ServiceDeleteResult = & sc.exe delete $Service.Name 2>&1
                Write-Output "Service delete output for $($Service.Name): $ServiceDeleteResult"
            }
            
            Start-Sleep -Seconds 2
            
            # Verify services are deleted
            $AllDeleted = $true
            foreach ($ServiceName in $ServiceNames) {
                $IsServiceDeleted = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                
                if ($IsServiceDeleted) {
                    Write-Output "Service $ServiceName still exists. Delete failed."
                    $AllDeleted = $false
                } else {
                    Write-Output "Service $ServiceName forcibly deleted successfully."
                }
            }
            
            if ($AllDeleted) {
                Exit 0
            } else {
                Exit 1
            }
        } else {
            Write-Output "N-able software uninstalled successfully."
            Exit 0
        }
    } catch {
        Write-Output "Error occurred during processing: $_"
        Exit 1
    }
} else {
    Write-Output "None of the specified services were found."
    Exit 0
}

Stop-Transcript
