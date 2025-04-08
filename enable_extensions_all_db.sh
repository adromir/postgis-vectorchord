#!/bin/sh
# Script to enable extensions in all user databases of a PostgreSQL instance
# Prompts for username and password. Uses stty for password input compatibility.

set -e # Exits immediately if a command exits with a non-zero status.

# --- Configuration ---
# PG_USER="${PG_USER:-postgres}" # REMOVED - Will prompt user instead
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"

# List of extensions to enable (space-separated)
EXTENSIONS_TO_ENABLE="postgis postgis_topology postgis_raster postgis_tiger_geocoder vectors"
# --- End Configuration ---

# --- Get Credentials ---
PG_USER_INPUT=""
while [ -z "$PG_USER_INPUT" ]; do
  # Prompt for username
  read -p "Enter PostgreSQL username (must have superuser rights or rights to create extensions): " PG_USER_INPUT
  if [ -z "$PG_USER_INPUT" ]; then
    echo "Username cannot be empty."
  fi
done

# Prompt for password securely using stty (more portable than read -s)
echo -n "Enter password for user '$PG_USER_INPUT': " # -n prevents newline before input
stty -echo # Disable terminal echo
read PG_PASSWORD_INPUT # Read password
stty echo # Enable terminal echo again
echo # Add a newline after the password input for cleaner output
# Export PGPASSWORD environment variable for psql commands to use automatically
export PGPASSWORD="$PG_PASSWORD_INPUT"
# --- End Get Credentials ---


# Create a comma-separated list for the search_path
# Assumption: Extension name matches schema name (true for postgis*, vectors)
SCHEMA_LIST=$(echo "$EXTENSIONS_TO_ENABLE" | tr ' ' ',')

echo "Connecting as user '$PG_USER_INPUT' to host '$PG_HOST:$PG_PORT'..."

# Get the list of all databases that are not templates and are not named 'postgres'
# Use the provided username
DATABASES=$(psql -U "$PG_USER_INPUT" -h "$PG_HOST" -p "$PG_PORT" -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');")

# Check psql exit status after getting databases
if [ $? -ne 0 ]; then
    echo "Error connecting to PostgreSQL or listing databases. Check credentials and connection parameters."
    unset PGPASSWORD # Clear password variable
    exit 1
fi


if [ -z "$DATABASES" ]; then
    echo "No user databases found to process (excluding template*, postgres)."
    # Unset PGPASSWORD before exiting
    unset PGPASSWORD
    exit 0
fi

echo "The following databases will be processed:"
echo "$DATABASES"
echo "---"

# Loop through each database
echo "$DATABASES" | while IFS= read -r DB; do
    # Remove leading/trailing whitespace (sometimes added by psql)
    DB=$(echo "$DB" | xargs)
    if [ -z "$DB" ]; then
        continue
    fi

    echo "Processing database: '$DB'"
    echo "Enabling extensions: $EXTENSIONS_TO_ENABLE"

    # Build the SQL commands together
    SQL_COMMANDS=""
    for EXT in $EXTENSIONS_TO_ENABLE; do
        SQL_COMMANDS="${SQL_COMMANDS}CREATE EXTENSION IF NOT EXISTS \"$EXT\";"
    done
    # Add the command to set the search path
    # Important: \$user must be escaped so it is interpreted by PostgreSQL, not the shell
    SQL_COMMANDS="${SQL_COMMANDS}ALTER DATABASE \"$DB\" SET search_path = \"\\\$user\", public, ${SCHEMA_LIST};"
    # Add commands for verification - Corrected SQL for PG16+
    SQL_COMMANDS="${SQL_COMMANDS}SELECT extname FROM pg_extension;" # List extensions in current DB
    SQL_COMMANDS="${SQL_COMMANDS}SELECT current_setting('search_path');"

    # Execute the commands for the current database using the provided username
    # PGPASSWORD environment variable is used automatically by psql
    # Use -v ON_ERROR_STOP=1 instead of \set within --command
    psql -U "$PG_USER_INPUT" -h "$PG_HOST" -p "$PG_PORT" -d "$DB" --quiet -v ON_ERROR_STOP=1 -c "${SQL_COMMANDS}"

    # Check psql exit status for this database (optional, set -e handles it)
    # if [ $? -ne 0 ]; then
    #     echo "Error processing database '$DB'."
    #     # Decide whether to continue or exit
    # fi

    echo "Database '$DB' processed successfully."
    echo "---"

done

# Unset PGPASSWORD after use for security
unset PGPASSWORD

echo "Extension enabling process completed."

