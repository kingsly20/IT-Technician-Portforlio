# File Encryption Automation: EFS and BitLocker

Scripts for automating Windows file and disk encryption, built while studying access control and encryption for CIS 401.

## EFS vs BitLocker

Windows gives you two ways to encrypt data, and they solve different problems.

EFS protects individual files or folders. It's tied to a specific Windows user account, so on a shared machine you can encrypt your own files without touching anyone else's. If someone steals the file, they can't open it without your certificate.

BitLocker protects the whole drive. It doesn't care which user is logged in. If a laptop gets stolen and the disk is BitLocker-protected, the thief can't read anything on it without the recovery key.

Pick EFS when you need to protect specific sensitive files on a system other people also use. Pick BitLocker when the risk is the whole device going missing, like a laptop or a USB drive. Many organisations run both: BitLocker on the disk, EFS on top for extra-sensitive files.

| | EFS | BitLocker |
|---|---|---|
| Protects | Individual files/folders | Entire drive |
| Tied to | A specific Windows user | The device itself |
| Best for | Shared machine, sensitive files | Lost or stolen laptop, USB drive |
| Recovery | Data Recovery Agent or personal certificate | 48-digit recovery key |

## Files in this folder

**Encrypt-Resource.ps1** wraps `cipher.exe` to apply EFS encryption to a file or folder. It supports recursion with `-Recurse`, logs every action with a timestamp, and checks each file's encryption attribute afterward instead of assuming the command worked.

**Decrypt-Resource.ps1** does the reverse. Same logging, same verification step.

## Usage

```powershell
# Encrypt one file
.\Encrypt-Resource.ps1 -Path "C:\Data\report.docx"

# Encrypt a folder and everything inside it
.\Encrypt-Resource.ps1 -Path "C:\Users\King\Documents\Confidential" -Recurse

# Decrypt it later
.\Decrypt-Resource.ps1 -Path "C:\Users\King\Documents\Confidential" -Recurse
```

Each run writes a log file. If a file fails to encrypt because it's on a FAT32 drive instead of NTFS, the log tells you exactly that, instead of leaving you to guess why nothing happened.

## Setting up BitLocker

BitLocker involves choices that are best made by a person, not a script: whether to unlock with TPM or a password, and where to store the recovery key. The steps:

1. Open Settings > Update & Security > Device Encryption, or Control Panel > BitLocker Drive Encryption.
2. Turn on BitLocker for the drive.
3. Choose TPM (automatic, if the hardware supports it) or a password/PIN.
4. Back up the recovery key. Save it to a Microsoft account, a file, or print it. Losing this key means losing the data if the normal unlock method fails.
5. Choose how much of the drive to encrypt and run it.
6. Confirm it worked: `manage-bde -status C:` from an elevated PowerShell prompt.

## What this shows

Command-line use of `cipher.exe`, not just the right-click GUI option. Scripts that log their actions and check the result, the same pattern needed for change management and audit trails in a real IT job. And a working grasp of when file-level encryption is the right tool versus when the whole disk needs protecting.
