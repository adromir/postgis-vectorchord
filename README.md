# 🐘 Postgres 17 + 🌍 PostGIS + 🎹 VectorChord

This Docker image provides a robust PostgreSQL 17 environment equipped with PostGIS and VectorChord (via pgvector) for advanced spatial and vector similarity search capabilities. It is built on the official `postgres:17-bookworm` image.

## ✨ Features

- **🐘 PostgreSQL 17**: Latest stable version on Debian Bookworm.
- **🌍 PostGIS 3**: Spatial database extender.
- **🔍 pgvector**: Open-source vector similarity search.
- **🎹 VectorChord**: High-performance vector search extension (v1.0.0).
- **⏰ Automated Backups**: Built-in cron scheduler for periodic backups.
- **🛠️ Backup & Restore Tools**: Scripts for manual backup and restore operations.

## 🚀 Usage

### 🐳 Docker Compose

```yaml
services:
  database:
    image: pg-vectorchord:17
    build: .
    environment:
      - POSTGRES_PASSWORD=mysecretpassword
      # Backup Configuration
      - BACKUP_SCHEDULE=0 2 * * *  # Run backup daily at 2:00 AM
      - BACKUP_RETENTION=7         # Keep the last 7 backups
    volumes:
      - pg-data:/var/lib/postgresql/data
      - ./backups:/backups         # Persist backups to host
    ports:
      - "5432:5432"

volumes:
  pg-data:
```

### 🔧 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | Superuser password for PostgreSQL. | (Required) |
| `BACKUP_SCHEDULE` | Cron expression for automated backups. If unset, cron is disabled. | Unset |
| `BACKUP_RETENTION` | Number of recent backups to keep. Older backups are deleted. | `0` (Keep all) |

### 💾 Volumes

- `/var/lib/postgresql/data`: PostgreSQL data directory.
- `/backups`: Directory where backup files are stored.

## 🔄 Backup and Restore

### ⏰ Automated Backups

To enable automated backups, set the `BACKUP_SCHEDULE` environment variable using standard cron syntax.
Example: `0 2 * * *` (Every day at 2:00 AM).

Backups are stored in the `/backups` directory with the naming convention:
- `all_databases_YYYYMMDD_HHMMSS.sql.gz` (Compressed SQL dump of all databases)

### 🛠️ Manual Backup

You can trigger a backup manually using the `backup.sh` script inside the container.

**Backup all databases (compressed):**
```bash
docker exec -it <container_name> backup.sh -c
```

**Backup a specific database:**
```bash
docker exec -it <container_name> backup.sh -d <dbname>
```

**Options:**
- `-c`: Compress output (gzip).
- `-d <dbname>`: Backup specific database.
- `-r <count>`: Apply retention policy (keep last N backups).
- `-p <path>`: Output path (default: `/backups`).

### ♻️ Restore

You can restore a database using the `restore.sh` script.

**Restore from a file:**
```bash
docker exec -it <container_name> restore.sh /backups/all_databases_20251203_120000.sql.gz
```

**Restore to a specific database:**
```bash
docker exec -it <container_name> restore.sh -d <dbname> /backups/my_backup.sql
```

**Note:** The script automatically detects if the file is compressed (`.gz`) and handles it accordingly.
