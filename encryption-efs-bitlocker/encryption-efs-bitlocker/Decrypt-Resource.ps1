<#
.SYNOPSIS
    Decrypts a file or folder (recursively) that was encrypted with EFS.

.DESCRIPTION
    Wraps cipher.exe to remove EFS encryption from a target path. Supports
    recursive decryption, logs each action, and verifies the resulting
    encryption attribute on each item.

.PARAMETER Path
    The file or folder to decrypt.

.PARAMETER Recurse
    If set, decrypts all files and subfolders under Path.

.PARAMETER LogFile
    Optional path to write a log of actions taken. Defaults to .\decrypt-log.txt
    in the current directory.

.EXAMPLE
    .\Decrypt-Resource.ps1 -Path "C:\Users\King\Documents\Confidential" -Recurse

.EXAMPLE
    .\Decrypt-Resource.ps1 -Path "C:\Data\report.docx"

.NOTES
    Only the user who encrypted the file (or a registered Data Recovery Agent)
    can successfully decrypt it. Running this as a different user will fail
    with an access-denied error from cipher.exe. That failure is itself a
    useful demonstration of EFS's per-user protection model.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [switch]$Recurse,

    [string]$LogFile = ".\decrypt-log.txt"
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

Write-Log "Starting EFS decryption for: $Path (Recurse: $($Recurse.IsPresent))"

# Build cipher.exe arguments
# /D   = decrypt
# /A   = apply to files as well as folders
# /S:  = recurse into subdirectories
$cipherArgs = @("/D", "/A")
if ($Recurse) {
    $cipherArgs += "/S:$Path"
} else {
    $cipherArgs += "`"$Path`""
}

try {
    $output = & cipher.exe @cipherArgs 2>&1
    foreach ($line in $output) {
        if ($line -match "^\[OK\]") {
            Write-Log "Decrypted: $line"
        }
        elseif ($line -match "Access is denied|error", "i") {
            Write-Log "FAILED (expected if not the encrypting user): $line"
        }
        else {
            Write-Log $line
        }
    }
    Write-Log "Decryption pass complete for: $Path"
}
catch {
    Write-Log "ERROR: cipher.exe failed - $($_.Exception.Message)"
    exit 1
}

# Verify: confirm encryption attribute has been cleared
Write-Log "Verifying decryption status..."
$items = if ($Recurse) { Get-ChildItem -Path $Path -Recurse -File } else { Get-Item -Path $Path }
foreach ($item in $items) {
    $isEncrypted = ($item.Attributes -band [System.IO.FileAttributes]::Encrypted) -eq [System.IO.FileAttributes]::Encrypted
    $status = if ($isEncrypted) { "STILL ENCRYPTED" } else { "DECRYPTED" }
    Write-Log "$($item.FullName): $status"
}

Write-Log "Done."
