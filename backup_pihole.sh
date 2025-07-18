#!/bin/bash

BACKUP_DIR="$1"
LOG_FILE="$2"
NAS_PORT="$3"
NAS_USER="$4"
NAS_HOST="$5"

if [ -z "$BACKUP_DIR" ] || [ -z "$LOG_FILE" ] || [ -z "$NAS_PORT" ] || [ -z "$NAS_USER" ] || [ -z "$NAS_HOST" ]; then
  echo "BACKUP_DIR, LOG_FILE, NAS_PORT, NAS_USER, and NAS_HOST are required."
  exit 1
fi

echo "====== [ BEGIN BACKUP LOG ENTRY ] ======" >> "$LOG_FILE"
echo "$(date +'%Y-%m-%d %H:%M:%S') - Running Pi-hole backup" >> "$LOG_FILE"

sudo pihole-FTL --teleporter # new backup

BACKUP_FILE=$(ls -t *.zip | head -n 1)

if [ -n "$BACKUP_FILE" ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Backup successful: $BACKUP_FILE" >> "$LOG_FILE"

    BACKUPS_TO_DELETE=$(ls -tp *.zip | grep -v '/$' | tail -n +4)  # List backups, keeping 3 newest
    if [ ! -z "$BACKUPS_TO_DELETE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Deleting old backups:" >> "$LOG_FILE"
        echo "- [DELETING] $BACKUPS_TO_DELETE" >> "$LOG_FILE"
        rm -f $BACKUPS_TO_DELETE  # Force delete without asking for confirmation
    fi

    # Sync only files to NAS / Destination Device using rsync, (redirect stdout & stderr to Log file)
    # -----------------------------------------------------------------------------------
    echo "$(date '+%Y-%m-%d %H:%M:%S') --> Syncing backups to NAS" >> "$LOG_FILE"
    rsync -av --include="*.zip" --exclude="*" --delete -e "ssh -p $NAS_PORT" "$BACKUP_DIR" "$NAS_USER@$NAS_HOST:./" >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sync successful" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sync failed!" >> "$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup failed: No backup file found!" >> "$LOG_FILE"
fi

# Add a demarcation line to mark the end of the primary backup operations
# -----------------------------------------------------------------------
echo "------ [END of BACKUP AND SYNC] ------" >> "$LOG_FILE"

# Sync the log file to the NAS
# -------------------------------------------------------------------------------------
rsync -av --include="*.log" --exclude="*" "ssh -p $NAS_PORT" "$BACKUP_DIR" "$NAS_USER@$NAS_HOST:./" > /dev/null 2>&1