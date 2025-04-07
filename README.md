# PostgreSQL + PostGIS + pgvector-rs Docker Image

## Overview

This document describes how to use a pre-built Docker image based on `postgres:17-alpine`. It includes:

* **PostgreSQL 17** (from the official Alpine-based image)
* **PostGIS** extension (version determined by Alpine package repository)
* **pgvector-rs** extension (v0.4.0, built from source)

The pre-built image is available on Docker Hub: **[adromir/postgis-pgvecto-rs](https://hub.docker.com/repository/docker/adromir/postgis-pgvecto-rs/general)** (Tag: `testing`).

The `postgis` and `vector` (pgvector-rs) extensions are automatically enabled in the default database upon first container startup.

## Features

* PostgreSQL 17 on Alpine Linux
* PostGIS extension included
* pgvector-rs extension v0.4.0 included
* Automatic enabling of `postgis` and `vector` extensions on initialization
* Configurable user, password, and database name via environment variables
* Standard PostgreSQL port `5432` exposed
* Data persistence via Docker volumes

## Prerequisites

* Docker installed and running.

## Running the Container

### Using `docker run`

You need to provide environment variables for the initial database user and password.

Pull the image first (optional, docker run will do it if not present)
docker pull adromir/postgis-pgvecto-rs:testing

```docker run -d --name my-postgres-container -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mysecretpassword -e POSTGRES_DB=mydb -p 5432:5432 -v my-pgdata:/var/lib/postgresql/data \adromir/postgis-pgvecto-rs:testing ```
  
-d: Run the container in detached mode (in the background).\
--name my-postgres-container: Assign a name to the container.\
-e POSTGRES_USER=myuser: Sets the initial database username.\
-e POSTGRES_PASSWORD=mysecretpassword: Required. Sets the password for the initial user. Use a strong password!\
-e POSTGRES_DB=mydb: Sets the name of the initial database (defaults to the value of POSTGRES_USER if not set).\
-p 5432:5432: Maps port 5432 on your host machine to port 5432 in the container.\
-v my-pgdata:/var/lib/postgresql/data: Crucial for persistence. Mounts a named Docker volume my-pgdata to the PostgreSQL data directory inside the container. Docker creates the volume if it doesn't exist. You can also use a host path like /path/on/host:/var/lib/postgresql/data.\
adromir/postgis-pgvecto-rs:testing: The pre-built image from Docker Hub.

### Using docker-composeCreate a docker-compose.yml file in your project directory:
```yaml
version: '3.8'
services:
  postgres:
    image: adromir/postgis-pgvecto-rs:testing # Use the pre-built image from Docker Hub
    container_name: my-postgres-container
    environment:
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mysecretpassword # Use secrets in production!
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"
    volumes:
      - my-pgdata:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  my-pgdata:
    # driver: local # Default driver
```
```bash Run Docker Compose:docker-compose up -d```

This will pull the image if necessary and start the PostgreSQL container in the background. To stop it, use docker-compose down.Connecting to the DatabaseYou can connect using any standard PostgreSQL client, such as
 
```bash psql:psql -h localhost -p 5432 -U myuser -d mydb```

Enter the password (mysecretpassword in the examples) when prompted.
Verifying Extensions Once connected, you can verify that the extensions are enabled:

List all installed extensions:

```sql SELECT * FROM pg_extension; ```

You should see postgis and vector listed. 
### Data Persistence
The PostgreSQL data is stored in the directory /var/lib/postgresql/data inside the container. It is highly recommended to use a named Docker volume (as shown in the examples) or a host
