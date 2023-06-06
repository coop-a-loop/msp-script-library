# $targetRepository = Get-VBRBackupRepository | Out-GridView -Title "Select your backup copy target repository" -OutputMode Single
#$encryptionKey = Get-VBREncryptionKey | Out-GridView -Title "Select the encryption key (use the one that's most recent or documented)" -OutputMode Single
# $description = Read-Host "Enter the ticket # this change is associated with"\

Start-Transcript -Path $env:WINDIR\logs\veeam-add-backup-copy-job.log

# Get timestamp
Write-Host "Getting timestamp."
$timeStamp = [int](Get-Date -UFormat %s -Millisecond 0)

# Set variables
Write-Host "Setting variables."
$targetRepository = Get-VBRBackupRepository | Where -Property Description -like "*$bucketName*"
$encryptionKey = Get-VBREncryptionKey | Sort ModificationDate -Descending | Select -First 1
$windowOption = New-VBRBackupWindowOptions -FromDay Monday -FromHour 06 -ToDay Saturday -ToHour 20
$scheduleOption = New-VBRPeriodicallyOPtions -FullPeriod 1 -PeriodicallyKind Hours -PeriodicallySchedule $windowOption
$storageOptions = New-VBRBackupCopyJobStorageOptions -EnableEncryption -EncryptionKey $encryptionKey -CompressionLevel Auto -EnableDataDeduplication -StorageOptimizationType Automatic
$backupJobs = Get-VBRJob | Where -Property Type -ne "Backup Copy"
# $schedule = New-VBRServerScheduleOptions -Type Periodically -PeriodicallyOptions $scheduleOption -EnableRetry -RetryCount 3 -RetryTimeout 30 -EnableBackupTerminationWindow -TerminationWindow $windowOption
$schedule = New-VBRServerScheduleOptions -Type Periodically -PeriodicallyOptions $scheduleOption -EnableRetry -RetryCount 3 -RetryTimeout 30

Write-Host "The varialbes are now set."
Write-Host "Repository target: $targetRepository"
Write-Host "Encryption key: $encryptionKey"
Write-Host "Window option: $windowOption"
Write-Host "Schedule option: $scheudleOption"
Write-Host "Storage options: $storageOptions"
Write-Host "Backup jobs: $backupJobs"
Write-Host "Schedule: $schedule"

# Add Backup copy job for all jobs.
Write-Host "Adding backup copy job for all backup jobs."
Add-VBRBackupCopyJob -BackupJob $backupJobs -ScheduleOptions $schedule  -Description "$description" -Mode periodic -Name "S3 Copy $timestamp" -ProcessLatestAvailablePoint -RetentionNumber 30 -RetentionType RestoreDays -StorageOptions $storageOptions -TargetRepository $targetRepository  -DirectOperation

Stop-Transcript