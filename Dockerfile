# Final PostgreSQL image using official Debian-based PostGIS image
# Installs pgvector-rs from pre-compiled .deb package
FROM postgis/postgis:17-3.4 AS final

# pgvector-rs .deb package URL and version
ARG PGVECTOR_RS_VERSION=0.4.0
ARG DEB_URL=https://github.com/tensorchord/pgvecto.rs/releases/download/v${PGVECTOR_RS_VERSION}/vectors-pg17_${PGVECTOR_RS_VERSION}_amd64.deb
ARG DEB_TMP_PATH=/tmp/vectors-pg17.deb

# Set locale environment variables (good practice)
ENV LANG=C.UTF-8

# PostGIS is already included in the base image

# Install dependencies for download, download .deb, install .deb, modify config, cleanup
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates sed && \
    \
    echo "Downloading pgvector-rs .deb package from ${DEB_URL}..." && \
    wget -q "${DEB_URL}" -O "${DEB_TMP_PATH}" && \
    \
    echo "Installing ${DEB_TMP_PATH}..." && \
    # Use apt-get install to handle potential dependencies of the .deb
    apt-get install -y "${DEB_TMP_PATH}" && \
    \
    # Modify the default postgresql.conf.sample to preload vectors.so
    # This ensures the setting is present when initdb creates the cluster configuration.
    CONF_SAMPLE_FILE=/usr/share/postgresql/17/postgresql.conf.sample && \
    LIB_TO_ADD='vectors.so' && \
    PARAM_NAME='shared_preload_libraries' && \
    echo "Modifying ${CONF_SAMPLE_FILE} to preload ${LIB_TO_ADD}..." && \
    # Case 1: Line exists (commented/uncommented) and value is NOT empty ('...')
    if grep -qE "^[#\s]*${PARAM_NAME}\s*=\s*'.'[^']*'.*" "$CONF_SAMPLE_FILE"; then \
        echo "Appending to existing non-empty value..."; \
        # Append comma and lib inside quotes, ensure uncommented
        sed -i -E "s/^[#\s]*(${PARAM_NAME}\s*=\s*'[^']*)'/\1,${LIB_TO_ADD}'/" "$CONF_SAMPLE_FILE"; \
    # Case 2: Line exists (commented/uncommented) and value IS empty ('')
    elif grep -qE "^[#\s]*${PARAM_NAME}\s*=\s*''" "$CONF_SAMPLE_FILE"; then \
        echo "Setting value in existing empty list..."; \
        # Replace '' with 'lib', ensure uncommented
        sed -i -E "s/^[#\s]*${PARAM_NAME}\s*=\s*''/${PARAM_NAME} = '${LIB_TO_ADD}'/" "$CONF_SAMPLE_FILE"; \
    # Case 3: Line doesn't exist (or doesn't use single quotes - less likely in sample)
    else \
        echo "Adding ${PARAM_NAME} line."; \
        echo "${PARAM_NAME} = '${LIB_TO_ADD}'" >> "$CONF_SAMPLE_FILE"; \
    fi && \
    # Final check: Ensure the line exists and is uncommented (redundant but safe)
    sed -i -E "s/^[#\s]*(${PARAM_NAME})/\1/" "$CONF_SAMPLE_FILE"; \
    echo "Verifying change in ${CONF_SAMPLE_FILE}:" && \
    grep "^${PARAM_NAME}" "$CONF_SAMPLE_FILE" || echo "${PARAM_NAME} line not found or commented." && \
    \
    echo "Cleaning up..." && \
    rm "${DEB_TMP_PATH}" && \
    # Keep sed installed if needed by base image scripts, remove wget/ca-certificates
    apt-get purge -y --auto-remove wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy initialization script (init-extensions.sql)
# Ensure this file exists in the build context (same directory as Dockerfile)
COPY init-extensions.sql /docker-entrypoint-initdb.d/

# --- NEU: Skript zum Aktivieren von Erweiterungen hinzufügen ---
# Copy the script into the image's binary path
COPY enable_extensions_all_db.sh /usr/local/bin/enable_extensions_all_db.sh
# Make the script executable
RUN chmod +x /usr/local/bin/enable_extensions_all_db.sh
# --- Ende NEU ---

# Expose the standard PostgreSQL port (likely inherited, but good practice)
EXPOSE 5432

# Declare the data directory as a volume (likely inherited, but good practice)
VOLUME /var/lib/postgresql/data

# The entrypoint and default command are inherited from the 'postgis/postgis' base image.
# It handles DB initialization, POSTGRES_USER/POSTGRES_PASSWORD, starting the server,
# and executing scripts in /docker-entrypoint-initdb.d/

