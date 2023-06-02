## Please note this script can only support the following backup repository types ##
# S3 Compabitble & Local. Both are forced.

Start-Transcript -Path $env:WINDIR\logs\veeam-add-backup-repo.log

Write-Host "Checking if we are running from a RMM or not."

if ($rmm -ne 1) { 
    # Set the repository details
    # $repositoryType = "Please enter the repository type (1 S3 Compatible; 2 Windows Local; 3 Both)"
    $description = Read-Host "Please enter the ticket # or project ticket # related to this configuration"
    $immutabilityPeriod = Read-Host "Enter how many days every object is immutable for"
    # $repositoryName = Read-Host "Enter the repository name" | Out-String
    $accessKey = Read-Host "Enter the access key"
    $secretKey = Read-Host "Enter the secret key"
    $endpoint = Read-Host "Enter the S3 endpoint url"
    $regionId = Read-Host "Enter the region ID"
    $bucketName = Read-Host "Enter the bucket name"

}

# Make sure PSModulePath includes Veeam Console
$MyModulePath = "C:\Program Files\Veeam\Backup and Replication\Console\"
$env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$MyModulePath"
if ($Modules = Get-Module -ListAvailable -Name Veeam.Backup.PowerShell) {
    try {
        $Modules | Import-Module -WarningAction SilentlyContinue
        }
        catch {
            throw "Failed to load Veeam Modules"
            }
    }

# Set Timestamp
$timeStamp = [int](Get-Date -UFormat %s -Millisecond 0)
$folderName = $timeStamp

# Add the S3 Account
$account = Add-VBRAmazonAccount -AccessKey $accessKey -SecretKey $secretKey -Description "$description $bucketName"

# Create the S3 repository
$connect = Connect-VBRAmazonS3CompatibleService -Account $account -CustomRegionId $regionId -ServicePoint $endpoint
$bucket = Get-VBRAmazonS3Bucket -Connection $connect -Name $bucketName
$folder = New-VBRAmazonS3Folder -Name $folderName -Connection $connect -Bucket $bucket
Add-VBRAmazonS3CompatibleRepository -AmazonS3Folder $folder -Connection $connect -Name "S3 $timeStamp" -EnableBackupImmutability -ImmutabilityPeriod $immutabilityPeriod -Description "$description $bucketName"



# Display the added repository details
$repository

# Get all logical drives on the system
$drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

# Find the drive with the largest total capacity
$largestDrive = $drives | Sort-Object -Property Size -Descending | Select-Object -First 1

# Set the local repository details
$repositoryName = "Local $timeStamp"
$repositoryPath = Join-Path -Path $largestDrive.DeviceID -ChildPath "\veeam\$timeStamp"

# Create the local repository
$repository = Add-VBRBackupRepository -Type WinLocal -Name $repositoryName -Folder $repositoryPath -Description "$description"

# Display the added repository details
$repository


############## Move backups

$backups = Get-VBRBackup
$repository = Get-VBRBackupRepository -Name "Local $timeStamp"

$backups | ForEach-Object {
     Move-VBRBackup -Repository $repository -Backup $_ -RunAsync
 }