#!/bin/sh
# Script to selectively enable extensions in user databases of a PostgreSQL instance
# Lists databases with extension status, prompts for selection by number(s).

set -e # Exits immediately if a command exits with a non-zero status.

# --- Configuration ---
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
# List of extensions to manage (space-separated) - CHANGED to vchord
EXTENSIONS_TO_ENABLE="postgis postgis_topology postgis_raster postgis_tiger_geocoder vchord"
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
echo -n "Enter password for user '$PG_USER_INPUT': "
stty -echo
read PG_PASSWORD_INPUT
stty echo
echo
export PGPASSWORD="$PG_PASSWORD_INPUT"
# --- End Get Credentials ---

# Create a comma-separated list for the search_path
SCHEMA_LIST=$(echo "$EXTENSIONS_TO_ENABLE" | tr ' ' ',')

echo "Connecting as user '$PG_USER_INPUT' to host '$PG_HOST:$PG_PORT'..."
echo "Fetching database list and checking extension status..."

# Get the list of all non-template databases (including 'postgres')
# Use -A for unaligned output, easier parsing
DATABASES_RAW=$(psql -U "$PG_USER_INPUT" -h "$PG_HOST" -p "$PG_PORT" -d postgres -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;")

# Check psql exit status
if [ $? -ne 0 ]; then
		echo "Error connecting to PostgreSQL or listing databases. Check credentials and connection parameters."
		unset PGPASSWORD
		exit 1
fi

if [ -z "$DATABASES_RAW" ]; then
		echo "No non-template databases found."
		unset PGPASSWORD
		exit 0
fi

# --- Gather Status Info ---
DB_COUNT=0
# Use temporary files for storing lists (more robust for names with spaces than pure shell vars)
TMP_DB_NAMES=$(mktemp)
TMP_DB_STATUS=$(mktemp)
# Ensure temp files are removed on exit, regardless of how the script exits
# shellcheck disable=SC2064 # Variable is expanded correctly at trap definition time
trap 'rm -f "$TMP_DB_NAMES" "$TMP_DB_STATUS"' EXIT

echo "$DATABASES_RAW" | while IFS= read -r DB; do
		if [ -z "$DB" ]; then continue; fi # Skip empty lines

		DB_COUNT=$((DB_COUNT + 1))
		echo "$DB" >> "$TMP_DB_NAMES" # Store DB name in temp file
		STATUS_LINE=""

		# Get currently installed extensions in this DB
		INSTALLED_EXTS=$(psql -U "$PG_USER_INPUT" -h "$PG_HOST" -p "$PG_PORT" -d "$DB" -t -A -c "SELECT extname FROM pg_extension;" 2>/dev/null || echo "ERROR_CHECKING")

		if [ "$INSTALLED_EXTS" = "ERROR_CHECKING" ]; then
				STATUS_LINE="Error checking status"
		else
				FIRST_EXT=1
				for EXT in $EXTENSIONS_TO_ENABLE; do
						if [ $FIRST_EXT -eq 0 ]; then STATUS_LINE="${STATUS_LINE}, "; fi
						# Use grep -Fxq for exact, whole-line, quiet match (case sensitive)
						if echo "$INSTALLED_EXTS" | grep -Fxq "$EXT"; then
								STATUS_LINE="${STATUS_LINE}${EXT}=YES"
						else
								STATUS_LINE="${STATUS_LINE}${EXT}=NO"
						fi
						FIRST_EXT=0
				done
		fi
		 echo "$STATUS_LINE" >> "$TMP_DB_STATUS" # Store status line in temp file
done

# --- Display Numbered List ---
echo "--------------------------------------------------"
echo "Available Databases and Extension Status:"
echo "--------------------------------------------------"
CURRENT_LINE=1
# Use paste to combine lines from the temp files
paste -d'|' "$TMP_DB_NAMES" "$TMP_DB_STATUS" | while IFS='|' read -r DBNAME DBSTATUS; do
		 # Ensure DBNAME is not empty before printing
		 if [ -n "$DBNAME" ]; then
					printf "[%2d] %-20s (Status: %s)\n" "$CURRENT_LINE" "$DBNAME" "$DBSTATUS"
					CURRENT_LINE=$((CURRENT_LINE + 1))
		 fi
done
echo "--------------------------------------------------"

# --- Prompt for Selection ---
SELECTED_DBS_INDICES="" # Store indices (numbers)
while true; do # Loop until valid input or cancel
		read -p "Enter database number(s) to process (e.g., 1 or 1,3,4), or 'all', or leave empty to cancel: " SELECTION_INPUT

		if [ -z "$SELECTION_INPUT" ]; then
				echo "Operation cancelled."
				unset PGPASSWORD
				# trap will clean up temp files
				exit 0
		fi

		# Handle 'all' case
		if echo "$SELECTION_INPUT" | grep -qiw "all"; then
				 SELECTED_DBS_INDICES=$(seq 1 $DB_COUNT)
				 echo "Selected all databases."
				 break # Exit selection loop
		fi

		# Validate input: replace commas, check if numbers, check range
		VALID_SELECTION=""
		INVALID_FOUND=0
		INPUT_NUMBERS=$(echo "$SELECTION_INPUT" | tr ',' ' ')

		for NUM in $INPUT_NUMBERS; do
				# Trim whitespace from NUM just in case
				NUM=$(echo "$NUM" | xargs)
				if [ -z "$NUM" ]; then continue; fi # Skip empty elements resulting from multiple commas etc.

				# Check if it's a positive integer
				if ! echo "$NUM" | grep -Eq '^[1-9][0-9]*$'; then
						echo "Invalid input: '$NUM' is not a valid positive number."
						INVALID_FOUND=1
						continue # Skip to next number in input
				fi
				# Check if number is in range
				if [ "$NUM" -gt "$DB_COUNT" ]; then
						echo "Invalid input: Number '$NUM' is out of range (1-$DB_COUNT)."
						INVALID_FOUND=1
						continue # Skip to next number in input
				fi
				# Add valid number to list (space separated) - avoid duplicates
				if ! echo " $VALID_SELECTION " | grep -q " $NUM "; then
						 VALID_SELECTION="${VALID_SELECTION}${NUM} "
				fi
		done

		# Check if any valid numbers were entered and no invalid input was found
		if [ $INVALID_FOUND -eq 0 ] && [ -n "$VALID_SELECTION" ]; then
				SELECTED_DBS_INDICES=$(echo "$VALID_SELECTION" | xargs) # Trim whitespace
				echo "Selected database numbers: $SELECTED_DBS_INDICES"
				break # Exit selection loop
		else
				echo "Invalid input detected. Please try again or leave empty to cancel."
				# Loop continues to ask for input again
		fi
done

# --- Process Selected Databases ---
echo "---"
echo "Processing selected databases..."
PROCESSED_COUNT=0
if [ -z "$SELECTED_DBS_INDICES" ]; then
		echo "No valid database numbers were selected."
else
		for NUM in $SELECTED_DBS_INDICES; do
				# Get the DB name for the selected number using sed on the temp file
				DB=$(sed -n "${NUM}p" "$TMP_DB_NAMES")

				if [ -z "$DB" ]; then
						 echo "Warning: Could not retrieve database name for index $NUM. Skipping."
						 continue
				fi

				echo "Processing database: '$DB' (Number $NUM)"
				PROCESSED_COUNT=$((PROCESSED_COUNT + 1))

				# Build the SQL commands together
				SQL_COMMANDS=""
				for EXT in $EXTENSIONS_TO_ENABLE; do
						SQL_COMMANDS="${SQL_COMMANDS}CREATE EXTENSION IF NOT EXISTS \"$EXT\";"
				done
				SQL_COMMANDS="${SQL_COMMANDS}ALTER DATABASE \"$DB\" SET search_path = \"\\\$user\", public, ${SCHEMA_LIST};"
				SQL_COMMANDS="${SQL_COMMANDS}SELECT extname FROM pg_extension;" # Verification
				SQL_COMMANDS="${SQL_COMMANDS}SELECT current_setting('search_path');" # Verification

				# Execute the commands
				psql -U "$PG_USER_INPUT" -h "$PG_HOST" -p "$PG_PORT" -d "$DB" --quiet -v ON_ERROR_STOP=1 -c "${SQL_COMMANDS}"
				echo "Database '$DB' processed successfully."
				echo "---"
		done
fi

# Unset PGPASSWORD after use for security
unset PGPASSWORD

if [ $PROCESSED_COUNT -eq 0 ]; then
		echo "No databases were selected or processed."
else
		echo "Finished processing $PROCESSED_COUNT selected database(s)."
fi
echo "Script finished."
