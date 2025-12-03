#!/bin/bash
set -e

# Default values
BACKUP_PATH="/backups"
RETENTION=0
COMPRESS=false
DB_NAME=""
POSTGRES_USER="${POSTGRES_USER:-postgres}"


# Parse arguments
while getopts "d:r:cp:" opt; do
  case $opt in
    d) DB_NAME="$OPTARG" ;;
    r) RETENTION="$OPTARG" ;;
    c) COMPRESS=true ;;
    p) BACKUP_PATH="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Ensure backup directory exists
mkdir -p "$BACKUP_PATH"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -n "$DB_NAME" ]; then
    FILENAME="${BACKUP_PATH}/${DB_NAME}_${TIMESTAMP}.sql"
    echo "Backing up database: $DB_NAME to $FILENAME"
    if [ "$COMPRESS" = true ]; then
        pg_dump -U "$POSTGRES_USER" "$DB_NAME" | gzip > "${FILENAME}.gz"
        echo "Backup completed: ${FILENAME}.gz"
    else
        pg_dump -U "$POSTGRES_USER" "$DB_NAME" > "$FILENAME"
        echo "Backup completed: ${FILENAME}"
    fi
else
    FILENAME="${BACKUP_PATH}/all_databases_${TIMESTAMP}.sql"
    echo "Backing up all databases to $FILENAME"
    if [ "$COMPRESS" = true ]; then
        pg_dumpall -U "$POSTGRES_USER" | gzip > "${FILENAME}.gz"
        echo "Backup completed: ${FILENAME}.gz"
    else
        pg_dumpall -U "$POSTGRES_USER" > "$FILENAME"
        echo "Backup completed: ${FILENAME}"
    fi
fi

# Retention policy
if [ "$RETENTION" -gt 0 ]; then
    echo "Applying retention policy: keeping last $RETENTION backups..."
    # Find files in backup path, sort by modification time (newest first), skip first N, and delete the rest
    # We filter by the type of backup we just made (single db or all) to avoid deleting other backups
    if [ -n "$DB_NAME" ]; then
        PREFIX="${DB_NAME}_"
    else
        PREFIX="all_databases_"
    fi
    
    find "$BACKUP_PATH" -name "${PREFIX}*" -type f -printf '%T@ %p\n' | sort -rn | tail -n +$((RETENTION + 1)) | cut -d' ' -f2- | xargs -r rm
    echo "Retention policy applied."
fi
