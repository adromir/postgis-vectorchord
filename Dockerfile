#
# Final, multi-architecture PostgreSQL Dockerfile
# Based on the official Debian-based PostGIS image
# Installs 'VectorChord' v0.4.2 from a pre-compiled .deb package from the official repository
#
FROM postgis/postgis:17-3.4 AS final

# --- Configuration for VectorChord ---
# Version 0.4.2 and the correct repository are used.
ARG VECTORCHORD_VERSION=0.4.2
ARG DEB_REPO=tensorchord/VectorChord

# --- Arguments for multi-architecture build ---
# TARGETARCH is automatically set by 'docker buildx' (e.g., amd64, arm64)
ARG TARGETARCH
ARG DEB_URL
ARG DEB_TMP_PATH=/tmp/vectorchord-pg17.deb

# Set the locale environment variable
ENV LANG=C.UTF-8

# PostGIS is already included in the base image.

# Install dependencies, download the .deb package, install it, adjust the configuration, and clean up.
RUN \
	# Set the DEB_URL based on the architecture.
	DEB_ARCH_SUFFIX=$(echo "${TARGETARCH:-amd64}" | sed 's/amd64/amd64/' | sed 's/arm64/arm64/') && \
	if [ -z "$DEB_URL" ]; then \
		DEB_URL="https://github.com/${DEB_REPO}/releases/download/v${VECTORCHORD_VERSION}/postgresql-17-vchord_${VECTORCHORD_VERSION}-1_${DEB_ARCH_SUFFIX}.deb"; \
	fi && \
	\
	apt-get update && \
	apt-get install -y --no-install-recommends wget ca-certificates sed && \
	\
	echo "Downloading VectorChord .deb package for ARCH ${DEB_ARCH_SUFFIX} from ${DEB_URL}..." && \
	wget -q "${DEB_URL}" -O "${DEB_TMP_PATH}" && \
	\
	echo "Installing ${DEB_TMP_PATH}..." && \
	# Use apt-get install to resolve dependencies of the .deb package
	apt-get install -y "${DEB_TMP_PATH}" && \
	\
	# Modify postgresql.conf.sample to preload vchord.so.
	# The extension file is named 'vchord.so' according to the .deb packages.
	CONF_SAMPLE_FILE=/usr/share/postgresql/17/postgresql.conf.sample && \
	LIB_TO_ADD='vchord.so' && \
	PARAM_NAME='shared_preload_libraries' && \
	echo "Modifying ${CONF_SAMPLE_FILE} to preload ${LIB_TO_ADD}..." && \
	# Case 1: Line exists (commented/uncommented) and value is NOT empty ('...')
	if grep -qE "^[#\s]*${PARAM_NAME}\s*=\s*'.'[^']*'.*" "$CONF_SAMPLE_FILE"; then \
		echo "Appending to existing non-empty value..."; \
		sed -i -E "s/^[#\s]*(${PARAM_NAME}\s*=\s*'[^']*)'/\1,${LIB_TO_ADD}'/" "$CONF_SAMPLE_FILE"; \
	# Case 2: Line exists (commented/uncommented) and value IS empty ('')
	elif grep -qE "^[#\s]*${PARAM_NAME}\s*=\s*''" "$CONF_SAMPLE_FILE"; then \
		echo "Setting value in existing empty list..."; \
		sed -i -E "s/^[#\s]*${PARAM_NAME}\s*=\s*''/${PARAM_NAME} = '${LIB_TO_ADD}'/" "$CONF_SAMPLE_FILE"; \
	# Case 3: Line does not exist
	else \
		echo "Adding ${PARAM_NAME} line."; \
		echo "${PARAM_NAME} = '${LIB_TO_ADD}'" >> "$CONF_SAMPLE_FILE"; \
	fi && \
	# Final check: Ensure the line exists and is uncommented
	sed -i -E "s/^[#\s]*(${PARAM_NAME})/\1/" "$CONF_SAMPLE_FILE"; \
	echo "Verifying change in ${CONF_SAMPLE_FILE}:" && \
	grep "^${PARAM_NAME}" "$CONF_SAMPLE_FILE" || echo "${PARAM_NAME} line not found or commented." && \
	\
	echo "Cleaning up..." && \
	rm "${DEB_TMP_PATH}" && \
	apt-get purge -y --auto-remove wget ca-certificates && \
	rm -rf /var/lib/apt/lists/*

# Copy the initialization script.
# IMPORTANT: Ensure this script uses 'CREATE EXTENSION IF NOT EXISTS vchord;'
COPY init-extensions.sql /docker-entrypoint-initdb.d/

# Copy the helper script.
# IMPORTANT: Ensure this script uses 'vchord' in its configuration.
COPY enable_extensions_all_db.sh /usr/local/bin/enable_extensions_all_db.sh
RUN chmod +x /usr/local/bin/enable_extensions_all_db.sh

# Standard PostgreSQL port (inherited, but explicit is good practice)
EXPOSE 5432

# Declare the data directory as a volume (inherited, but explicit is good practice)
VOLUME /var/lib/postgresql/data

# ENTRYPOINT and CMD are inherited from the 'postgis/postgis' base image.
