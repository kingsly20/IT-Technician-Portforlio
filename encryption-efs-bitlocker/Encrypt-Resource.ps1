<#
.SYNOPSIS
    Encrypts a file or folder (recursively) using Windows Encrypting File System (EFS).

.DESCRIPTION
    Wraps cipher.exe to apply EFS encryption to a target path. Supports recursive
    encryption of all files and subfolders, logs each action, and reports any
    items that failed to encrypt (e.g. unsupported file systems, FAT volumes).

.PARAMETER Path
    The file or folder to encrypt.

.PARAMETER Recurse
    If set, encrypts all files and subfolders under Path.

.PARAMETER LogFile
    Optional path to write a log of actions taken. Defaults to .\encrypt-log.txt
    in the current directory.

.EXAMPLE
    .\Encrypt-Resource.ps1 -Path "C:\Users\King\Documents\Confidential" -Recurse

.EXAMPLE
    .\Encrypt-Resource.ps1 -Path "C:\Data\report.docx"

.NOTES
    Requires an NTFS volume. EFS is per-user: only the encrypting user (and any
    added Data Recovery Agents) can decrypt the files by default.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [switch]$Recurse,

    [string]$LogFile = ".\encrypt-log.txt"
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

if (-not (Test-Path -Path $Path)) {
    Write-Log "ERROR: Path '$Path' does not exist. Aborting."
    exit 1
}

$volume = (Get-Item $Path).PSDrive.Name + ":"
$fsType = (Get-Volume -DriveLetter (Get-Item $Path).PSDrive.Name).FileSystemType
if ($fsType -ne "NTFS") {
    Write-Log "ERROR: EFS requires NTFS. '$volume' is formatted as $fsType. Aborting."
    exit 1
}

Write-Log "Starting EFS encryption for: $Path (Recurse: $($Recurse.IsPresent))"

# Build cipher.exe arguments
# /E   = encrypt
# /A   = apply to files as well as folders
# /S:  = recurse into subdirectories (cipher's own recursion switch)
$cipherArgs = @("/E", "/A")
if ($Recurse) {
    $cipherArgs += "/S:$Path"
} else {
    $cipherArgs += "`"$Path`""
}

try {
    $output = & cipher.exe @cipherArgs 2>&1
    foreach ($line in $output) {
        if ($line -match "^\[OK\]") {
            Write-Log "Encrypted: $line"
        }
        elseif ($line -match "Access is denied|error", "i") {
            Write-Log "FAILED: $line"
        }
        else {
            Write-Log $line
        }
    }
    Write-Log "Encryption pass complete for: $Path"
}
catch {
    Write-Log "ERROR: cipher.exe failed - $($_.Exception.Message)"
    exit 1
}

# Verify: list encryption attribute status for reporting
Write-Log "Verifying encryption status..."
$items = if ($Recurse) { Get-ChildItem -Path $Path -Recurse -File } else { Get-Item -Path $Path }
foreach ($item in $items) {
    $isEncrypted = ($item.Attributes -band [System.IO.FileAttributes]::Encrypted) -eq [System.IO.FileAttributes]::Encrypted
    $status = if ($isEncrypted) { "ENCRYPTED" } else { "NOT ENCRYPTED" }
    Write-Log "$($item.FullName): $status"
}

Write-Log "Done."
