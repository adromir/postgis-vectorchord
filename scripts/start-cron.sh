#!/bin/bash
set -e

# Setup cron if BACKUP_SCHEDULE is set
if [ -n "$BACKUP_SCHEDULE" ]; then
    echo "Setting up backup cron job with schedule: $BACKUP_SCHEDULE"
    
    # Export environment variables for cron
    printenv | grep -v "no_proxy" >> /etc/environment
    
    # Create log file for cron
    touch /var/log/cron.log
    
    # Default backup options (can be overridden by env vars if we added them, but for now hardcoded basics + envs)
    # We'll assume the user wants to backup all DBs by default in the cron job.
    # We can add more env vars for retention etc later if needed, or just use defaults.
    # Let's use some reasonable defaults for the cron job: backup all, compress, keep 7.
    
    BACKUP_CMD="/usr/local/bin/backup.sh -c -r ${BACKUP_RETENTION:-7}"
    
    # Add cron job
    echo "$BACKUP_SCHEDULE $BACKUP_CMD >> /var/log/cron.log 2>&1" > /etc/cron.d/postgres-backup
    chmod 0644 /etc/cron.d/postgres-backup
    crontab /etc/cron.d/postgres-backup
    
    # Start cron
    cron
    echo "Cron service started."
fi

# Run the original entrypoint
exec docker-entrypoint.sh "$@"
