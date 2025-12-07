#!/bin/bash
# Docker Socket Setup Script for WSL2
# This script ensures Docker Desktop socket is properly linked

LOG_FILE="/tmp/docker-setup.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log "🐳 Starting Docker socket setup..."

# Wait for Docker Desktop to be available (max 60 seconds)
TIMEOUT=60
COUNTER=0

while [ ! -S /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock ]; do
    if [ $COUNTER -ge $TIMEOUT ]; then
        log "❌ Timeout waiting for Docker Desktop socket after ${TIMEOUT}s"
        exit 1
    fi
    
    log "⏳ Waiting for Docker Desktop... (${COUNTER}s)"
    sleep 2
    COUNTER=$((COUNTER + 2))
done

log "✅ Docker Desktop socket found"

# Remove existing socket if present
if [ -L /var/run/docker.sock ] || [ -S /var/run/docker.sock ]; then
    log "🗑️  Removing existing Docker socket"
    rm -f /var/run/docker.sock
fi

# Create symbolic link
log "🔗 Creating symbolic link to Docker Desktop"
ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock

# Set permissions
log "🔒 Setting socket permissions"
chmod 666 /var/run/docker.sock

# Verify setup
if docker version >/dev/null 2>&1; then
    log "✅ Docker setup completed successfully!"
    log "📊 Server version: $(docker info --format "{{.ServerVersion}}" 2>/dev/null)"
else
    log "❌ Docker setup verification failed"
    exit 1
fi

log "🎉 Docker socket setup complete!" 