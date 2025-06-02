# PostgreSQL + PostGIS + VectorChord Docker Image

[![Docker Image CI](https://github.com/adromir/postgis-vectorchord/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/adromir/postgis-vectorchord/actions/workflows/docker-publish.yml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/adromir/postgis-vectorchord)](https://github.com/adromir/postgis-vectorchord/releases/latest)
[![Docker Pulls](https://img.shields.io/docker/pulls/adromir/postgis-vectorchord.svg)](https://hub.docker.com/r/adromir/postgis-vectorchord)
[![Docker Image Size (latest)](https://img.shields.io/docker/image-size/adromir/postgis-vectorchord/latest)](https://hub.docker.com/r/adromir/postgis-vectorchord)
[![GitHub Stars](https://img.shields.io/github/stars/adromir/postgis-vectorchord.svg?style=social&label=Star)](https://github.com/adromir/postgis-vectorchord/stargazers/)
[![GitHub Forks](https://img.shields.io/github/forks/adromir/postgis-vectorchord.svg?style=social&label=Fork)](https://github.com/adromir/postgis-vectorchord/network/members)
[![GitHub issues](https://img.shields.io/github/issues/adromir/postgis-vectorchord.svg)](https://github.com/adromir/postgis-vectorchord/issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/adromir/postgis-vectorchord.svg)](https://github.com/adromir/postgis-vectorchord/commits/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![PostgreSQL Version](https://img.shields.io/badge/PostgreSQL-17-blue.svg)
![PostGIS Version](https://img.shields.io/badge/PostGIS-3.4-green.svg)
![VectorChord Version](https://img.shields.io/badge/VectorChord-0.4.2-orange.svg)

## Overview

This document describes how to use a pre-built Docker image based on `postgis/postgis:17-3.4`. It includes:

* **PostgreSQL 17** (from the official PostGIS image)
* **PostGIS** extension (3.4.x, corresponding to the base image)
* **VectorChord** extension (v0.4.2, official Debian Package)

The pre-built image is available on:
* **Docker Hub**: **[adromir/postgis-vectorchord](https://hub.docker.com/r/adromir/postgis-vectorchord)**
* **GitHub Container Registry**: **[ghcr.io/adromir/postgis-vectorchord](https://github.com/users/Adromir/packages/container/package/postgis-vectorchord)**

The `postgis` and `vchord` (VectorChord) extensions are automatically enabled in the default database upon first container startup.

## Features

* PostgreSQL 17
* PostGIS 3.4.x extension included
* VectorChord extension v0.4.2 included
* Automatic enabling of `postgis` and `vchord` extensions on initialization
* Configurable user, password, and database name via environment variables
* Standard PostgreSQL port `5432` exposed
* Data persistence via Docker volumes
* Multi-arch support (linux/amd64, linux/arm64)
* Automated builds and updates via GitHub Actions

## Prerequisites

* Docker installed and running.

## Running the Container

### Using `docker run`

You need to provide environment variables for the initial database user and password.

Pull the image first (optional, `docker run` will do it if not present):
```bash
docker pull adromir/postgis-vectorchord:latest
# or from GHCR
# docker pull ghcr.io/adromir/postgis-vectorchord:latest
```

Run the container:
```bash
docker run -d \
  --name my-postgres-container \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -v my-pgdata:/var/lib/postgresql/data \
  adromir/postgis-vectorchord:latest
```

* `-d`: Run the container in detached mode (in the background).
* `--name my-postgres-container`: Assign a name to the container.
* `-e POSTGRES_USER=myuser`: Sets the initial database username.
* `-e POSTGRES_PASSWORD=mysecretpassword`: Required. Sets the password for the initial user. Use a strong password!
* `-e POSTGRES_DB=mydb`: Sets the name of the initial database (defaults to the value of `POSTGRES_USER` if not set).
* `-p 5432:5432`: Maps port 5432 on your host machine to port 5432 in the container.
* `-v my-pgdata:/var/lib/postgresql/data`: Crucial for persistence. Mounts a named Docker volume `my-pgdata` to the PostgreSQL data directory inside the container. Docker creates the volume if it doesn't exist. You can also use a host path like `/path/on/host:/var/lib/postgresql/data`.
* `adromir/postgis-vectorchord:latest`: The pre-built image from Docker Hub. Use `ghcr.io/adromir/postgis-vectorchord:latest` for the GitHub Container Registry image.

### Using `docker-compose`

Create a `docker-compose.yml` file in your project directory:

```yaml
version: '3.8'
services:
  postgres:
    image: adromir/postgis-vectorchord:latest # Or ghcr.io/adromir/postgis-vectorchord:latest
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

Run Docker Compose:
```bash
docker-compose up -d
```

This will pull the image if necessary and start the PostgreSQL container in the background. To stop it, use `docker-compose down`.

## Connecting to the Database

You can connect using any standard PostgreSQL client, such as `psql`:
```bash
psql -h localhost -p 5432 -U myuser -d mydb
```
Enter the password (`mysecretpassword` in the examples) when prompted.

## Verifying Extensions

Once connected, you can verify that the extensions are enabled:

List all installed extensions:
```sql
SELECT * FROM pg_extension;
```
You should see `postgis` and `vchord` listed.

## Data Persistence

The PostgreSQL data is stored in the directory `/var/lib/postgresql/data` inside the container. It is highly recommended to use a named Docker volume (as shown in the examples) or a host path for data persistence.

## New Databases

To enable all extensions on new databases you create, run:
```bash
docker exec -it <container-name> enable_extensions_all_db.sh
```
This script will prompt you for the PostgreSQL username and password.

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

## License

This project is licensed under the MIT License.

Copyright (c) 2024 Adromir

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Source: [https://github.com/adromir/postgis-vectorchord](https://github.com/adromir/postgis-vectorchord)
