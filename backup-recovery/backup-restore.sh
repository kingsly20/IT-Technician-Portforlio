#!/usr/bin/env bash
#
# backup-restore.sh
#
# A small backup/recovery toolkit for Linux, covering three scenarios:
#   1. Standard backup of a file or directory
#   2. Restore from a standard backup
#   3. Forensic recovery of a deleted-but-still-open file, using its
#      process ID (PID) via /proc/<pid>/fd. This is the technique used when
#      a file has been deleted from disk but a running process still
#      holds an open file descriptor to it.
#
# Usage:
#   ./backup-restore.sh                     # interactive menu
#   ./backup-restore.sh backup <path>       # back up a file/directory
#   ./backup-restore.sh restore <archive>   # restore from a backup archive
#   ./backup-restore.sh recover-pid <pid> <fd_number> <output_path>
#
# All actions are logged to backup-restore.log in the current directory.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
LOG_FILE="./backup-restore.log"

log() {
    local msg="$1"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

ensure_backup_dir() {
    mkdir -p "$BACKUP_DIR"
}

# --- 1. Standard backup ------------------------------------------------

do_backup() {
    local target="$1"
    if [[ ! -e "$target" ]]; then
        log "ERROR: '$target' does not exist. Aborting backup."
        exit 1
    fi

    ensure_backup_dir
    local base
    base=$(basename "$target")
    local ts
    ts=$(date +"%Y%m%d-%H%M%S")
    local archive="${BACKUP_DIR}/${base}.${ts}.tar.gz"

    tar -czf "$archive" -C "$(dirname "$target")" "$base"
    log "Backed up '$target' -> '$archive'"
    echo "$archive"
}

# --- 2. Standard restore ------------------------------------------------

do_restore() {
    local archive="$1"
    local restore_to="${2:-./restored}"

    if [[ ! -f "$archive" ]]; then
        log "ERROR: Archive '$archive' not found. Aborting restore."
        exit 1
    fi

    mkdir -p "$restore_to"
    tar -xzf "$archive" -C "$restore_to"
    log "Restored '$archive' -> '$restore_to'"
}

# --- 3. Forensic recovery via PID / open file descriptor ----------------
#
# When a file is deleted while a process still has it open, the data is
# not actually freed on disk until that file descriptor is closed. On
# Linux, /proc/<pid>/fd/<fd_number> is a symlink to the (now-unlinked)
# file's data, so copying through that symlink recovers the content even
# though the file no longer has a name anywhere on the filesystem.

recover_via_pid() {
    local pid="$1"
    local fd="$2"
    local output_path="$3"
    local fd_path="/proc/${pid}/fd/${fd}"

    if [[ ! -e "$fd_path" ]]; then
        log "ERROR: '$fd_path' does not exist. Is PID $pid still running with fd $fd open?"
        exit 1
    fi

    # Confirm the fd actually points to a deleted file (sanity check, not required)
    if readlink "$fd_path" | grep -q "(deleted)"; then
        log "Confirmed: fd $fd on PID $pid points to a deleted file."
    else
        log "Warning: fd $fd on PID $pid does not appear to point to a deleted file. Proceeding anyway."
    fi

    cp "$fd_path" "$output_path"
    log "Recovered data from PID $pid, fd $fd -> '$output_path'"
}

# --- Menu ----------------------------------------------------------------

show_menu() {
    echo "=== Linux Backup & Recovery Toolkit ==="
    echo "1) Backup a file or directory"
    echo "2) Restore from a backup archive"
    echo "3) Forensic recovery via PID (deleted-but-open file)"
    echo "4) Exit"
    read -rp "Choose an option: " choice

    case "$choice" in
        1)
            read -rp "Path to back up: " target
            do_backup "$target"
            ;;
        2)
            read -rp "Path to backup archive: " archive
            read -rp "Restore to (default ./restored): " dest
            do_restore "$archive" "${dest:-./restored}"
            ;;
        3)
            read -rp "PID: " pid
            read -rp "File descriptor number (see: ls -la /proc/<pid>/fd): " fd
            read -rp "Output path for recovered file: " out
            recover_via_pid "$pid" "$fd" "$out"
            ;;
        4)
            exit 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# --- Entry point -----------------------------------------------------------

if [[ $# -eq 0 ]]; then
    show_menu
else
    case "$1" in
        backup)
            do_backup "$2"
            ;;
        restore)
            do_restore "$2" "${3:-./restored}"
            ;;
        recover-pid)
            recover_via_pid "$2" "$3" "$4"
            ;;
        *)
            echo "Usage: $0 [backup <path> | restore <archive> [dest] | recover-pid <pid> <fd> <output>]"
            exit 1
            ;;
    esac
fi
