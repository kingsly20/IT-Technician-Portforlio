# Cross-Platform Backup and Recovery

A Linux backup and restore toolkit, plus a comparison to how Windows handles the same problems. Built while studying operating systems and disaster recovery for CS 510.

## What's in this folder

**backup-restore.sh** is a menu-driven Bash tool with three functions:

1. Standard backup. Archives a file or directory to a timestamped `.tar.gz`.
2. Standard restore. Extracts an archive back to a target location.
3. Forensic recovery by PID. Recovers a file that was deleted while a process still had it open.

## Recovering a deleted file through its PID

Most people assume a deleted file is gone the moment you hit delete. On Linux, that's not quite right. Deleting a file removes its name from the directory. The data itself stays on disk until every process holding it open closes it.

If a process still has the file open when it gets deleted, you can pull the data back through `/proc/<pid>/fd/<fd_number>`, a symlink to the file's content that keeps working even though the file has no name anywhere on the filesystem.

```bash
# Find a process with a deleted file still open
lsof | grep deleted

# List its open file descriptors
ls -la /proc/<pid>/fd

# Copy the data back before the process exits
./backup-restore.sh recover-pid <pid> <fd_number> ./recovered-file.txt
```

This only works while the process is still running. Once it exits, the data is gone for good. But when it works, it's the difference between telling someone "sorry, that file's gone" and actually getting it back.

## Usage

```bash
chmod +x backup-restore.sh

# Backup
./backup-restore.sh backup /home/user/project

# Restore
./backup-restore.sh restore ./backups/project.20260101-120000.tar.gz ./restored

# Interactive menu
./backup-restore.sh
```

Every action gets logged with a timestamp to `backup-restore.log`. That log is what lets you explain to someone afterward exactly what you did during a recovery.

## How Windows handles the same problems

| Scenario | Linux (this toolkit) | Windows |
|---|---|---|
| Ad-hoc backup | `tar -czf` archive | File History, `robocopy` to a share, Windows Server Backup |
| Full system recovery | Disk imaging, distro recovery mode | System Restore, System Image Recovery |
| Centralised/VM backup | Tools like ArCycle, Veeam | Same tools, ArCycle and Veeam both support Hyper-V and VMware |
| Undelete after the fact | The PID trick, or `extundelete`/`testdisk` | Recycle Bin, File History previous versions, third-party undelete tools |

Different tools, same principle underneath: a real backup beats any recovery trick. The PID method and the Recycle Bin are both last resorts.

## What this shows

Real knowledge of how the Linux filesystem handles open and deleted files, not just command memorisation. A tool built with both a menu for interactive use and a CLI for scripting. And the ability to map a concept from one operating system onto its equivalent on another, which matters in a support role covering mixed environments.
