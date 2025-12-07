#!/bin/bash
# Script to notify after backup completion

# Get backup status from Duplicati environment variables
BACKUP_NAME="$DUPLICATI__backup_name"
BACKUP_STATUS="$DUPLICATI__parsed_result"
BACKUP_SIZE="$DUPLICATI__size"
BACKUP_DURATION="$DUPLICATI__duration"
BACKUP_FILES="$DUPLICATI__files"
BACKUP_TIME="$(date)"

# Log backup completion
echo "Backup of $BACKUP_NAME completed at $BACKUP_TIME with status: $BACKUP_STATUS"
echo "Size: $BACKUP_SIZE, Duration: $BACKUP_DURATION, Files: $BACKUP_FILES"

# You can add notification code here (email, webhook, etc.)
# Example for webhook notification:
# curl -X POST -H "Content-Type: application/json" -d "{\"text\":\"Backup $BACKUP_NAME completed with status $BACKUP_STATUS\"}" https://your-webhook-url

exit 0