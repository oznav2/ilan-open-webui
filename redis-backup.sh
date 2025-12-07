#!/bin/bash
set -e

BACKUP_DIR="/home/ilan/redis-data-backup"
CONTAINER_NAME="redis"
DATE=$(date +%Y%m%d_%H%M%S)

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

echo "Creating Redis backup to $BACKUP_DIR..."

# Create a backup of the Redis database
docker exec $CONTAINER_NAME redis-cli SAVE

# Copy the dump.rdb file from the container
docker cp $CONTAINER_NAME:/data/dump.rdb $BACKUP_DIR/dump.rdb

# Also backup the appendonly.aof file if it exists
docker cp $CONTAINER_NAME:/data/appendonly.aof $BACKUP_DIR/appendonly.aof 2>/dev/null || true

# Create a timestamped backup as well
mkdir -p $BACKUP_DIR/data/$DATE
cp $BACKUP_DIR/dump.rdb $BACKUP_DIR/data/$DATE/dump.rdb
if [ -f $BACKUP_DIR/appendonly.aof ]; then
  cp $BACKUP_DIR/appendonly.aof $BACKUP_DIR/data/$DATE/appendonly.aof
fi

echo "Redis backup completed successfully to $BACKUP_DIR"
echo "Timestamped backup created at $BACKUP_DIR/data/$DATE" 