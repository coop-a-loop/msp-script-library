# Getting input from user if not running from RMM else set variables from RMM.

$scriptLogName = "enter-your-script-log-name-here.log"

if ($rmm -ne 1) {
    $validInput = 0
    # Only running if S3 Copy Job is true for this part.
    while ($validInput -ne 1) {
        # Ask for input here. This is the interactive area for getting variable information.
        # Remember to make validInput = 1 whenever correct input is given.

    }
    $logPath = "$env:WINDIR\logs\$scriptLogName"
    $description = Read-Host "Please enter the ticket # and, or your initials. Its used as the description for the job"


} else { 
    # Store the logs in the rmmScriptPath
    $logPath = "$rmmScriptPath\logs\$scriptLogName"
    

}

Start-Transcript -Path $logPath

Write-Host "This script is being run for $description"

Stop-Transcript