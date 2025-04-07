# Stage 1: Build pgvector-rs extension (using Debian/Bookworm based builder)
# Using rust:1-bookworm as a base for potentially easier compilation
FROM rust:1-bookworm AS pgvector_builder

# Define pgvector-rs version and expected extracted directory name
ARG PGVECTOR_RS_VERSION=0.4.0
ARG PGVECTOR_RS_DIRNAME=pgvecto.rs-${PGVECTOR_RS_VERSION}
# Define the required cargo-pgrx version based on pgvector-rs dependencies
ARG CARGO_PGRX_VERSION=0.12.5

# Install dependencies needed for building pgvector-rs with pgrx on Debian/Ubuntu
# build-essential includes common tools like make, gcc, tar etc.
# postgresql-server-dev-17 provides pg_config for Postgres 17 (adjust version if needed)
# curl is needed to download the source tarball
# git is needed by cargo to fetch git dependencies (like pgrx itself)
# clang and llvm are often required by pgrx/bindgen
# libssl-dev provides OpenSSL development libraries
# pkg-config helps build scripts find libraries
RUN apt-get update && \
    # 1. Install prerequisites for adding external repositories and download tools
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && \
    # 2. Import PostgreSQL GPG key
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql-archive-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/postgresql-archive-keyring.gpg && \
    \
    # 3. Add PostgreSQL repository
    echo "deb [signed-by=/etc/apt/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    \
    # 4. Update package lists again after adding the new repo
    apt-get update && \
    \
    # 5. Install actual build dependencies (re-adding git)
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    clang \
    llvm \
    postgresql-server-dev-17 \
    libssl-dev \
    pkg-config \
    && \
    # Clean up apt cache and repo files
    rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/pgdg.list /etc/apt/keyrings/postgresql-archive-keyring.gpg


# Install the specific required version of the pgrx command-line tool
# Version must match the pgrx library version used by pgvector-rs v0.4.0
RUN cargo install cargo-pgrx --version ${CARGO_PGRX_VERSION} --locked

# Add cargo bin directory to PATH so we can run cargo-pgrx
ENV PATH="/usr/local/cargo/bin:${PATH}"

# Download and extract the specific pgvector-rs source tarball
RUN curl -fsSL https://github.com/tensorchord/pgvecto.rs/archive/refs/tags/v${PGVECTOR_RS_VERSION}.tar.gz -o pgvecto.rs-v${PGVECTOR_RS_VERSION}.tar.gz \
    && tar -xzf pgvecto.rs-v${PGVECTOR_RS_VERSION}.tar.gz \
    && rm pgvecto.rs-v${PGVECTOR_RS_VERSION}.tar.gz

# Set working directory to the extracted source code
WORKDIR /${PGVECTOR_RS_DIRNAME}

# Initialize pgrx for Postgres 17 using the pg_config from postgresql-server-dev-17
# This sets up the build environment for the correct Postgres version
RUN cargo pgrx init --pg17 /usr/lib/postgresql/17/bin/pg_config

# Build and install the extension in release mode for performance
# Removed '-j $(nproc)' as it's not a supported argument for 'cargo pgrx install'
# Cargo will still attempt parallel compilation internally by default.
RUN cargo pgrx install --release

# ---

# Stage 2: Final PostgreSQL image (remains Alpine based for small size)
# Using the official postgres:17-alpine image
FROM postgres:17-alpine

# Set locale environment variables to avoid potential issues
ENV LANG=C.UTF-8

# Install PostGIS extension package
# Using 'postgis' package name for Alpine
RUN apk add --no-cache postgis

# Copy the built pgvector-rs extension files from the builder stage
# Artifacts built on Debian/glibc should generally work with Alpine/musl Postgres,
# but this can sometimes cause subtle issues. Test carefully.
COPY --from=pgvector_builder /pgvecto.rs-*/target/release/pgvector_rs*.so /usr/local/lib/postgresql/
COPY --from=pgvector_builder /pgvecto.rs-*/target/release/pgvector_rs*.sql /usr/local/share/postgresql/extension/
# Note: The .control file might be directly in the source directory, not target/release after pgrx install
# Let's copy it from the WORKDIR set in the builder stage
COPY --from=pgvector_builder /pgvecto.rs-*/pgvector-rs.control /usr/local/share/postgresql/extension/


# Add SQL script to automatically enable extensions on first run
# This script will be executed by the entrypoint script after initdb
# Ensure 'init-extensions.sql' exists in the build context (same directory as Dockerfile)
COPY init-extensions.sql /docker-entrypoint-initdb.d/init-extensions.sql

# Expose the standard PostgreSQL port
# Mapping is done via `docker run -p`
EXPOSE 5432

# Declare the data directory as a volume
# This allows mapping it from the host or using Docker volumes for persistence
# The base image's entrypoint script manages this directory
VOLUME /var/lib/postgresql/data

# The entrypoint and default command are inherited from the base 'postgres:17-alpine' image.
# The entrypoint script handles:
# 1. Initializing the database cluster in /var/lib/postgresql/data if it's empty.
# 2. Creating the initial user and database based on environment variables:
#    - POSTGRES_USER (default: postgres)
#    - POSTGRES_PASSWORD (required if POSTGRES_USER is set, otherwise uses password 'postgres')
#    - POSTGRES_DB (default: same as POSTGRES_USER)
# 3. Executing scripts in /docker-entrypoint-initdb.d/ (like our init-extensions.sql).
# 4. Starting the PostgreSQL server.
# CMD ["postgres"] is the default command inherited.

