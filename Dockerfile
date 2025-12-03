FROM postgres:17-bookworm

# Install dependencies, PostGIS, pgvector, and cron
RUN apt-get update && apt-get install -y --no-install-recommends \
	curl \
	ca-certificates \
	cron \
	postgresql-17-postgis-3 \
	postgresql-17-postgis-3-scripts \
	postgresql-17-pgvector \
	&& rm -rf /var/lib/apt/lists/*

# Install VectorChord 1.0.0 from .deb
ARG VECTORCHORD_VERSION=1.0.0
# URL pattern: https://github.com/tensorchord/VectorChord/releases/download/1.0.0/postgresql-17-vchord_1.0.0-1_amd64.deb

RUN curl -fL "https://github.com/tensorchord/VectorChord/releases/download/${VECTORCHORD_VERSION}/postgresql-17-vchord_${VECTORCHORD_VERSION}-1_amd64.deb" -o /tmp/vectorchord.deb \
	&& apt-get install -y /tmp/vectorchord.deb \
	&& rm /tmp/vectorchord.deb

# Configure shared_preload_libraries
RUN echo "shared_preload_libraries = 'vchord'" >> /usr/share/postgresql/postgresql.conf.sample

# Copy initialization scripts
COPY init-extensions.sql /docker-entrypoint-initdb.d/

# Copy backup/restore scripts
COPY scripts/backup.sh scripts/restore.sh scripts/start-cron.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /usr/local/bin/start-cron.sh

VOLUME /backups
ENTRYPOINT ["start-cron.sh"]
CMD ["postgres"]

EXPOSE 5432
