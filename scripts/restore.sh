#!/bin/bash
set -e

# Default values
DB_NAME=""
POSTGRES_USER="${POSTGRES_USER:-postgres}"


# Parse arguments
while getopts "d:" opt; do
  case $opt in
    d) DB_NAME="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

shift $((OPTIND -1))
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 [-d dbname] <backup_file>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found."
    exit 1
fi

echo "Restoring from $BACKUP_FILE..."

# Check if compressed
if [[ "$BACKUP_FILE" =~ \.gz$ ]]; then
    if [ -n "$DB_NAME" ]; then
        echo "Restoring compressed backup to database: $DB_NAME"
        gunzip -c "$BACKUP_FILE" | psql -U "$POSTGRES_USER" -d "$DB_NAME"
    else
        echo "Restoring compressed backup (all databases)"
        gunzip -c "$BACKUP_FILE" | psql -U "$POSTGRES_USER" -d postgres
    fi
else
    if [ -n "$DB_NAME" ]; then
        echo "Restoring backup to database: $DB_NAME"
        psql -U "$POSTGRES_USER" -d "$DB_NAME" < "$BACKUP_FILE"
    else
        echo "Restoring backup (all databases)"
        psql -U "$POSTGRES_USER" -d postgres < "$BACKUP_FILE"
    fi
fi

echo "Restore completed."
