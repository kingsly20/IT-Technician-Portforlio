# Active Directory User and Permissions Provisioning

A PowerShell tool that creates AD users and groups, sets up their shared folders, and applies NTFS permissions, all from one CSV. Built while studying Windows access control and `icacls.exe`.

## Files in this folder

**New-ADProvision.ps1** reads a CSV and, for each row, creates the AD group if it doesn't exist, creates the user with a forced password change at first login, adds them to the group, creates the group's shared folder, and applies NTFS permissions through `icacls.exe`.

**sample-new-hires.csv** shows the expected format.

## Why this beats doing it by hand

Creating a handful of AD accounts through the GUI is fine. Creating twenty is slow and easy to get wrong, and real onboarding rarely happens one person at a time. A new starter, a new project team, a department reorg: these come in batches.

The script handles that with three things a manual process usually skips:

It checks before it creates. If a user, group, or folder already exists, it skips that step instead of failing or duplicating it. Run it twice on the same CSV and nothing breaks.

It logs everything. Every action, created or skipped, gets a timestamp in a log file. That's the audit trail an IT department actually needs when someone asks who has access to what and when they got it.

It verifies the result. After provisioning, the script queries each group's membership again and logs what it finds, rather than trusting that the earlier commands worked.

## Usage

```powershell
.\New-ADProvision.ps1 -CsvPath .\sample-new-hires.csv

# Point at a different OU
.\New-ADProvision.ps1 -CsvPath .\sample-new-hires.csv -DefaultOU "OU=Contractors,DC=lab,DC=local"
```

CSV columns:

| Column | What it does |
|---|---|
| Username | AD SamAccountName, e.g. jsmith |
| FullName | Display name for the new user |
| GroupName | Security group to create (if needed) and add the user to |
| FolderPath | Shared folder for the group, created if missing |
| Permission | Read, Modify, or FullControl, mapped to the matching icacls flags |

## What this shows

Real AD administration through scripting: user and group creation, group membership, OU placement, not just clicking through the GUI. NTFS permission management with `icacls.exe`, including translating a plain-English permission level into the correct inheritance flags. And a script built to be safe to re-run and to leave an audit trail, which is what real IT support work requires, not just what a lab exercise asks for.

## One note

This was built and tested in a lab AD environment, not a live production domain. The default OU, password, and domain suffix in the script are placeholders. Update them before running this against real infrastructure.
