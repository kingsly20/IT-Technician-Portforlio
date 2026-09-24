<#
.SYNOPSIS
    Provisions Active Directory users and groups, creates their home/shared
    folders, and applies NTFS permissions, all from a single CSV input.

.DESCRIPTION
    Reads a CSV of user/group/folder definitions and:
      1. Creates any AD groups that don't already exist
      2. Creates AD users and adds them to the specified group
      3. Creates a folder for each group (if it doesn't exist)
      4. Applies NTFS permissions via icacls so the group has access

    Every action is logged with a timestamp. The script is idempotent where
    possible. It checks for existing users, groups, and folders before
    creating them, rather than failing or duplicating.

.PARAMETER CsvPath
    Path to the input CSV. Expected columns:
    Username,FullName,GroupName,FolderPath,Permission

    Example row:
    jsmith,Jane Smith,Sales,C:\Shares\Sales,Modify

.PARAMETER LogFile
    Path to write the action log. Defaults to .\ad-provision-log.txt

.EXAMPLE
    .\New-ADProvision.ps1 -CsvPath .\new-hires.csv

.NOTES
    Requires the ActiveDirectory PowerShell module and appropriate permissions
    to create users/groups (run as a Domain Admin or delegated equivalent).
    Designed and tested in a lab AD environment as part of coursework on
    Windows access control and Group Policy administration.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,

    [string]$LogFile = ".\ad-provision-log.txt",

    [string]$DefaultOU = "OU=Staff,DC=lab,DC=local",

    [string]$DefaultPassword = "ChangeMe!2026"
)

Import-Module ActiveDirectory -ErrorAction Stop

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Ensure-Group {
    param([string]$GroupName)
    $existing = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Group '$GroupName' already exists, skipping creation."
    } else {
        New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path $DefaultOU
        Write-Log "Created group '$GroupName'."
    }
}

function Ensure-User {
    param([string]$Username, [string]$FullName, [string]$GroupName)
    $existing = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "User '$Username' already exists, skipping creation."
    } else {
        $securePwd = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
        New-ADUser -Name $FullName `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@lab.local" `
            -Path $DefaultOU `
            -AccountPassword $securePwd `
            -ChangePasswordAtLogon $true `
            -Enabled $true
        Write-Log "Created user '$Username' ($FullName)."
    }

    Add-ADGroupMember -Identity $GroupName -Members $Username -ErrorAction SilentlyContinue
    Write-Log "Added '$Username' to group '$GroupName'."
}

function Ensure-Folder {
    param([string]$FolderPath, [string]$GroupName, [string]$Permission)

    if (-not (Test-Path $FolderPath)) {
        New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
        Write-Log "Created folder '$FolderPath'."
    } else {
        Write-Log "Folder '$FolderPath' already exists, skipping creation."
    }

    # Apply NTFS permission for the group via icacls
    # Common Permission values: Read, Modify, FullControl
    $icaclsPerm = switch ($Permission) {
        "Read"          { "RX" }
        "Modify"        { "M" }
        "FullControl"   { "F" }
        default         { "RX" }
    }

    $result = & icacls.exe $FolderPath /grant "${GroupName}:(OI)(CI)$icaclsPerm" 2>&1
    Write-Log "Applied '$Permission' ($icaclsPerm) for '$GroupName' on '$FolderPath': $result"
}

# --- Main -----------------------------------------------------------------

Write-Log "Starting AD provisioning from CSV: $CsvPath"

$rows = Import-Csv -Path $CsvPath
$processedGroups = @{}

foreach ($row in $rows) {
    $groupName = $row.GroupName

    if (-not $processedGroups.ContainsKey($groupName)) {
        Ensure-Group -GroupName $groupName
        Ensure-Folder -FolderPath $row.FolderPath -GroupName $groupName -Permission $row.Permission
        $processedGroups[$groupName] = $true
    }

    Ensure-User -Username $row.Username -FullName $row.FullName -GroupName $groupName
}

Write-Log "Provisioning complete. Processed $($rows.Count) user row(s) across $($processedGroups.Count) group(s)."

# --- Verification pass ------------------------------------------------------

Write-Log "Verifying results..."
foreach ($group in $processedGroups.Keys) {
    $members = Get-ADGroupMember -Identity $group | Select-Object -ExpandProperty Name
    Write-Log "Group '$group' members: $($members -join ', ')"
}
