# Docker Desktop WSL2 Integration Troubleshooting Guide

## System Overview

### Environment Details
- **OS**: Windows with WSL2 (Ubuntu-20.04)
- **Docker Desktop**: v28.1.1 running on Windows
- **WSL Kernel**: 6.6.87.1-microsoft-standard-WSL2
- **Docker Client**: v28.1.1 (installed in WSL)
- **Docker Compose**: v2.35.1-desktop.1

### WSL Distributions
```
NAME              STATE           VERSION
* Ubuntu-20.04    Running         2
  docker-desktop  Running         2
```

## Problem Description

### Symptoms
1. **Windows PowerShell**: Docker works correctly with context `desktop-linux`
2. **WSL Ubuntu**: Docker commands fail with "Cannot connect to the Docker daemon"
3. **Docker Compose**: Cannot execute `docker-compose up` commands in WSL
4. **Context Issue**: WSL has `wsl-docker` context pointing to non-functional socket

### Error Messages
```bash
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

## Root Cause Analysis

### Primary Issue
The WSL configuration (`/etc/wsl.conf`) was attempting to create a symbolic link to an incorrect Docker socket path:
```bash
# Incorrect path in wsl.conf (BEFORE)
ln -s /wsl/docker-desktop/shared-sockets/guest-services/docker.sock /var/run/docker.sock
```

### Actual Docker Desktop Socket Location
Docker Desktop provides the socket at:
```bash
# Correct path (WORKING NOW)
/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
```

### Key Differences
1. **Mount Path**: `/mnt/wsl/` instead of `/wsl/`
2. **Socket Name**: `docker.proxy.sock` instead of `docker.sock`
3. **Permissions**: Socket needs proper permissions for user access

## ✅ **Current Working Configuration**

### Verified Working Paths
```bash
# Primary Docker Socket (Application Endpoint)
/var/run/docker.sock
├── Type: Symbolic link
├── Target: /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
├── Permissions: lrwxrwxrwx (link) → 666 (target)
└── Owner: root:root

# Docker Desktop Source Socket (Windows Integration)
/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
├── Type: Unix socket (Docker Desktop provided)
├── Permissions: srw-rw-rw- (666)
├── Owner: root:root
└── Status: ✅ Active and working
```

### Working Docker Context Configuration
```bash
# Active Context Details
Context: wsl-docker (*)
Endpoint: unix:///var/run/docker.sock
Status: ✅ Connected to Docker Server v28.1.1

# Available Contexts
NAME            ENDPOINT                                    STATUS
default         unix:///var/run/docker.sock               Available
desktop-linux   npipe:////./pipe/dockerDesktopLinuxEngine  ⚠️ WSL Incompatible
wsl-docker *    unix:///var/run/docker.sock               ✅ Active & Working
```

### Working WSL Configuration (/etc/wsl.conf)
```ini
[boot]
systemd=true
command="bash ngrok http --domain=ai.ilanel.co.il 8080 & rm -f /var/run/docker.sock && ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock && chmod 666 /var/run/docker.sock"

[user]
default=ilan

[automount]
enabled=true
root=/mnt/
options="metadata,umask=22,fmask=11"
mountFsTab=true

[filesystem]
umask=022

[interop]
enabled=true
appendWindowsPath=true

[network]
generateHosts=true
generateResolvConf=true
```

## Solution Implementation

### Step 1: Verify Docker Desktop Socket
```bash
# Check available Docker sockets
ls -la /mnt/wsl/docker-desktop/shared-sockets/guest-services/

# Verify the proxy socket exists and permissions
stat /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock

# Expected output:
# Access: (0666/srw-rw-rw-)  Uid: (    0/    root)   Gid: (    0/    root)
```

### Step 2: Create Correct Symbolic Link
```bash
# Remove existing broken link
sudo rm -f /var/run/docker.sock

# Create correct symbolic link
sudo ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock

# Set appropriate permissions
sudo chmod 666 /var/run/docker.sock

# Verify the link
ls -la /var/run/docker.sock
# Expected: lrwxrwxrwx 1 root root 71 → /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
```

### Step 3: Verify Connection
```bash
# Test Docker connectivity
docker version
# Expected: Client: 28.1.1 | Server: 28.1.1

docker ps
# Should show running containers

# Test Docker Compose
docker-compose --version
# Expected: Docker Compose version v2.35.1-desktop.1

docker-compose config
# Should parse your compose file successfully
```

## Permanent Fix

### Update /etc/wsl.conf
The corrected `/etc/wsl.conf` with proper socket path:

```ini
[boot]
systemd=true
command="bash ngrok http --domain=ai.ilanel.co.il 8080 & rm -f /var/run/docker.sock && ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock && chmod 666 /var/run/docker.sock"

[user]
default=ilan

[automount]
enabled=true
root=/mnt/
options="metadata,umask=22,fmask=11"
mountFsTab=true

[filesystem]
umask=022

[interop]
enabled=true
appendWindowsPath=true

[network]
generateHosts=true
generateResolvConf=true
```

### Path Correction Summary
| Component | ❌ **Incorrect (Before)** | ✅ **Correct (Working)** |
|-----------|---------------------------|---------------------------|
| **Mount Base** | `/wsl/docker-desktop/...` | `/mnt/wsl/docker-desktop/...` |
| **Socket Name** | `docker.sock` | `docker.proxy.sock` |
| **Full Path** | `/wsl/docker-desktop/shared-sockets/guest-services/docker.sock` | `/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock` |

### Alternative Startup Script
Create a more robust startup script:

```bash
#!/bin/bash
# File: /usr/local/bin/setup-docker-socket.sh

# Wait for Docker Desktop to be ready
DOCKER_SOCKET="/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock"

while [ ! -S "$DOCKER_SOCKET" ]; do
    echo "Waiting for Docker Desktop..."
    sleep 2
done

# Remove existing socket if present
rm -f /var/run/docker.sock

# Create symbolic link
ln -s "$DOCKER_SOCKET" /var/run/docker.sock

# Set permissions
chmod 666 /var/run/docker.sock

echo "Docker socket configured successfully"
echo "Link: /var/run/docker.sock → $DOCKER_SOCKET"
```

## Docker Context Management

### Available Contexts
```bash
# List all contexts
docker context ls

# Expected output:
NAME            DESCRIPTION                               DOCKER ENDPOINT
default         Current DOCKER_HOST based configuration   unix:///var/run/docker.sock
desktop-linux   Docker Desktop                            npipe:////./pipe/dockerDesktopLinuxEngine
wsl-docker *                                              unix:///var/run/docker.sock
```

### Cross-Platform Context Analysis

#### **Complete Context Inventory**

**🪟 Windows PowerShell Docker Contexts:**
| Context Name | Status | Endpoint | Description | Purpose |
|--------------|--------|----------|-------------|---------|
| **`default`** | Available | `npipe:////./pipe/docker_engine` | Current DOCKER_HOST based configuration | Legacy Docker Engine connection |
| **`desktop-linux`** | ✅ **ACTIVE** | `npipe:////./pipe/dockerDesktopLinuxEngine` | Docker Desktop | ✅ **Primary Windows connection** |
| **`wsl-docker`** | Available | `unix:///var/run/docker.sock` | WSL context (shared) | ❌ **Invalid in Windows** (no Unix sockets) |

**🐧 WSL (Ubuntu-20.04) Docker Contexts:**
| Context Name | Status | Endpoint | Description | Purpose |
|--------------|--------|----------|-------------|---------|
| **`default`** | Available | `unix:///var/run/docker.sock` | Current DOCKER_HOST based configuration | Standard Unix socket connection |
| **`desktop-linux`** | Available | `npipe:////./pipe/dockerDesktopLinuxEngine` | Docker Desktop | ⚠️ **WSL Incompatible** (causes segfaults) |
| **`wsl-docker`** | ✅ **ACTIVE** | `unix:///var/run/docker.sock` | Custom WSL context | ✅ **Primary WSL connection** |

#### **Context Redundancy Analysis**

**🔴 High Redundancy (Exact Duplicates):**
1. **WSL**: `default` ↔ `wsl-docker`
   - Identical endpoints: `unix:///var/run/docker.sock`
   - Identical functionality
   - Both functional, `wsl-docker` currently active

**🟡 Medium Redundancy (Similar Purpose):**
2. **Windows**: `default` ↔ `desktop-linux`
   - Different engines but both Windows named pipes
   - `default`: `npipe:////./pipe/docker_engine` (legacy)
   - `desktop-linux`: `npipe:////./pipe/dockerDesktopLinuxEngine` (current)

**🟢 Cross-Platform Issues (Not True Redundancy):**
3. **`desktop-linux`** exists in both environments:
   - Windows: ✅ Works with named pipe
   - WSL: ❌ Crashes with "protocol not available" error
4. **`wsl-docker`** exists in both environments:
   - Windows: ❌ Invalid (Windows has no Unix sockets)
   - WSL: ✅ Works with Unix socket

#### **Context Sharing Behavior**
Docker contexts are **shared between Windows and WSL**, stored in:
- **Windows**: `C:\Users\ilane\.docker\contexts\`
- **WSL**: `/home/ilan/.docker/contexts/`

This explains why the same context names appear in both environments but with different behaviors per platform.

#### **Context Storage Locations**

**WSL Context Storage Structure:**
```bash
/home/ilan/.docker/contexts/
├── meta/
│   ├── bc6198af0f191f5cc5df88fde7ee83ac755872d9d451d21d5b12541e0d4782fd/  # wsl-docker context
│   └── fe9c6bd7a66301f49ca9b6a70b217107cd1284598bfc254700c989b916da791e/  # desktop-linux context
└── tls/
    ├── bc6198af0f191f5cc5df88fde7ee83ac755872d9d451d21d5b12541e0d4782fd/
    └── fe9c6bd7a66301f49ca9b6a70b217107cd1284598bfc254700c989b916da791e/
```

**Windows Context Storage Structure:**
```
C:\Users\ilane\.docker\contexts\
├── meta\
│   ├── bc6198af0f191f5cc5df88fde7ee83ac755872d9d451d21d5b12541e0d4782fd\  # wsl-docker context
│   └── fe9c6bd7a66301f49ca9b6a70b217107cd1284598bfc254700c989b916da791e\  # desktop-linux context
└── tls\
    ├── bc6198af0f191f5cc5df88fde7ee83ac755872d9d451d21d5b12541e0d4782fd\
    └── fe9c6bd7a66301f49ca9b6a70b217107cd1284598bfc254700c989b916da791e\
```

**Context Hash Mapping:**
- **`bc6198af...d4782fd`**: `wsl-docker` context metadata and TLS data
- **`fe9c6bd7...6da791e`**: `desktop-linux` context metadata and TLS data
- **`default`**: Stored in memory (no persistent files)

**Storage Commands:**
```bash
# View WSL context storage
ls -la ~/.docker/contexts/meta/

# View context hash mapping
docker context ls --format "table {{.Name}}\t{{.DockerEndpoint}}"

# Inspect specific context storage
docker context inspect wsl-docker --format "{{.Storage.MetadataPath}}"
docker context inspect desktop-linux --format "{{.Storage.MetadataPath}}"
```

#### **Current Working Configuration**
```bash
# Windows PowerShell
Active Context: desktop-linux (*)
Endpoint: npipe:////./pipe/dockerDesktopLinuxEngine
Status: ✅ Working with Docker Desktop

# WSL Ubuntu-20.04
Active Context: wsl-docker (*)
Endpoint: unix:///var/run/docker.sock → /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
Status: ✅ Working (Client 28.1.1 ↔ Server 28.1.1)
```

### Context Switching
```bash
# Use WSL socket (recommended after fix)
docker context use wsl-docker

# Use Windows Docker Desktop directly (⚠️ has compatibility issues from WSL)
docker context use desktop-linux

# Use default socket
docker context use default
```

### Context Verification
```bash
# Check current context
docker context show
# Expected: wsl-docker

# Verify context connectivity
docker version --format "Context: {{.Client.Context}} | Client: {{.Client.Version}} | Server: {{.Server.Version}}"
# Expected: Context: wsl-docker | Client: 28.1.1 | Server: 28.1.1
```

## User Permissions

### Add User to Docker Group
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Verify group membership
groups
# Expected to include: ilan root adm dialout cdrom floppy sudo audio dip video plugdev netdev ollama docker
```

### Socket Permissions Verification
```bash
# Check socket permissions
stat /var/run/docker.sock

# Expected output:
# Access: (0777/lrwxrwxrwx)  Uid: (    0/    root)   Gid: (    0/    root)
```

## Troubleshooting Commands

### Diagnostic Commands
```bash
# 1. Check WSL distribution status
wsl -l -v

# 2. Verify Docker Desktop is running (Windows PowerShell)
docker context use desktop-linux && docker info

# 3. Check Docker socket status in WSL
ls -la /var/run/docker.sock

# 4. Verify Docker Desktop socket availability
ls -la /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock

# 5. Test Docker connectivity with detailed info
docker version --format "Client: {{.Client.Version}} | Server: {{.Server.Version}}"
docker info --format "Server Version: {{.ServerVersion}} | Context: $(docker context show)"

# 6. Check Docker contexts
docker context ls
docker context show

# 7. Test Docker Compose
docker-compose --version
docker-compose config
```

### Verification Script
```bash
#!/bin/bash
# Complete Docker Setup Verification

echo "🔍 Docker Setup Verification"
echo "============================="

echo "1. Docker Desktop Socket:"
if [ -S /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock ]; then
    echo "   ✅ Found: $(stat -c '%A %U:%G' /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock)"
else
    echo "   ❌ Not found - Docker Desktop may not be running"
fi

echo "2. WSL Docker Socket Link:"
if [ -L /var/run/docker.sock ]; then
    echo "   ✅ Link exists: $(ls -la /var/run/docker.sock | cut -d' ' -f9-)"
else
    echo "   ❌ Socket link missing"
fi

echo "3. Docker Connectivity:"
if docker version >/dev/null 2>&1; then
    echo "   ✅ Connected: $(docker version --format 'Client {{.Client.Version}} | Server {{.Server.Version}}')"
    echo "   📋 Context: $(docker context show)"
else
    echo "   ❌ Connection failed"
fi

echo "4. Docker Compose:"
if docker-compose --version >/dev/null 2>&1; then
    echo "   ✅ Available: $(docker-compose --version)"
else
    echo "   ❌ Not working"
fi
```

### Common Issues and Solutions

#### Issue 1: "Protocol not available" error
**Symptom**: `Failed to initialize: protocol not available`
**Cause**: Using `desktop-linux` context from WSL
**Solution**: 
```bash
docker context use wsl-docker
```

#### Issue 2: Permission denied
**Symptom**: `permission denied while trying to connect to the Docker daemon socket`
**Solution**: 
```bash
sudo chmod 666 /var/run/docker.sock
# Or add user to docker group and restart WSL
sudo usermod -aG docker $USER
```

#### Issue 3: Socket not found
**Symptom**: `No such file or directory` for docker.sock
**Solution**: 
```bash
# Recreate the symbolic link with correct path
sudo rm -f /var/run/docker.sock
sudo ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock
```

#### Issue 4: Wrong socket target
**Symptom**: Socket exists but Docker still can't connect
**Solution**: 
```bash
# Check if link points to correct socket
ls -la /var/run/docker.sock
# Should point to: /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock

# If wrong, recreate with correct path
sudo rm -f /var/run/docker.sock
sudo ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock
```

#### Issue 5: Docker Desktop not starting
**Solution**: 
1. Restart Docker Desktop from Windows
2. Wait for all WSL distributions to show "Running" status: `wsl -l -v`
3. Verify socket availability: `ls -la /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock`
4. Recreate link if needed

#### Issue 6: Context confusion between Windows and WSL
**Symptom**: Docker works in one environment but not the other, or contexts seem to conflict
**Cause**: Docker contexts are shared between Windows and WSL but behave differently per platform
**Analysis**:
```bash
# Check current context in WSL
docker context show
# Expected: wsl-docker

# Check current context in Windows PowerShell
docker context show
# Expected: desktop-linux

# Verify context endpoints match platform
docker context inspect $(docker context show)
```
**Solution**:
```bash
# In WSL - use Unix socket contexts
docker context use wsl-docker
# or
docker context use default

# In Windows PowerShell - use named pipe contexts  
docker context use desktop-linux
# or
docker context use default
```

#### Issue 7: Redundant contexts causing confusion
**Symptom**: Multiple contexts with similar names or functionality
**Analysis**: 
- **WSL**: `default` and `wsl-docker` are functionally identical (both use `unix:///var/run/docker.sock`)
- **Windows**: `default` and `desktop-linux` both use named pipes but different engines
- **Cross-platform**: Same context names exist in both environments with different behaviors

**Current Working Setup** (no changes needed):
```bash
# Windows: desktop-linux (active) - npipe:////./pipe/dockerDesktopLinuxEngine
# WSL: wsl-docker (active) - unix:///var/run/docker.sock
```

**Optional Cleanup** (when ready):
```bash
# WSL - Remove duplicate (choose one):
# docker context rm default  # (keep wsl-docker for clarity)

# Windows - Remove legacy (if not needed):
# docker context rm default  # (keep desktop-linux as primary)
```

## Best Practices

### 1. Startup Sequence
1. Start Docker Desktop on Windows
2. Wait for WSL distributions to be ready (`wsl -l -v`)
3. Verify Docker Desktop socket exists
4. Create/verify Docker socket link
5. Test connectivity before running containers

### 2. Context Management
- Use `wsl-docker` context for WSL operations
- Keep `desktop-linux` for Windows-specific operations when needed
- Avoid mixing contexts in the same session
- Always verify context with `docker context show`

### 3. Permission Management
- Use docker group membership instead of sudo when possible
- Set socket permissions in startup script (666)
- Verify permissions after WSL restarts
- Check both link and target permissions

### 4. Path Verification
```bash
# Always verify these paths match exactly:
EXPECTED_SOURCE="/mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock"
EXPECTED_TARGET="/var/run/docker.sock"

# Verification command:
[ "$(readlink /var/run/docker.sock)" = "$EXPECTED_SOURCE" ] && echo "✅ Correct path" || echo "❌ Wrong path"
```

### 5. Monitoring
```bash
# Monitor Docker socket status
watch -n 5 'echo "Socket: $(ls -la /var/run/docker.sock 2>/dev/null || echo "Missing")" && echo "Docker: $(docker info --format "{{.ServerVersion}}" 2>/dev/null || echo "Not connected")" && echo "Context: $(docker context show 2>/dev/null || echo "Unknown")"'
```

## System Information Reference

### Windows Docker Desktop Info
```
Client:
 Version:    28.1.1
 Context:    desktop-linux
 Debug Mode: false

Server:
 Containers: 42
  Running: 24
  Paused: 0
  Stopped: 18
 Images: 117
 Server Version: 28.1.1
 Storage Driver: overlayfs
 Kernel Version: 6.6.87.1-microsoft-standard-WSL2
 Operating System: Docker Desktop
```

### WSL Docker Client Info
```
Client: Docker Engine - Community
 Version:           28.1.1
 API version:       1.49
 Go version:        go1.23.8
 Git commit:        4eba377
 Built:             Fri Apr 18 09:52:18 2025
 OS/Arch:           linux/amd64
 Context:           wsl-docker
```

### Current Working Socket Configuration
```bash
# Socket Link Details
/var/run/docker.sock → /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
├── Link permissions: lrwxrwxrwx (777)
├── Target permissions: srw-rw-rw- (666)
├── Owner: root:root
├── Docker context: wsl-docker
└── Status: ✅ Working (Client: 28.1.1 | Server: 28.1.1)
```

## Recovery Procedures

### Complete Reset
If all else fails:
```bash
# 1. Stop all containers
docker stop $(docker ps -aq) 2>/dev/null

# 2. Reset Docker context
docker context use wsl-docker

# 3. Remove docker socket
sudo rm -f /var/run/docker.sock

# 4. Restart WSL
# In Windows PowerShell: wsl --shutdown
# Wait 10 seconds, then start WSL again

# 5. Recreate socket link with verified working path
sudo ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock

# 6. Test connectivity
docker version --format "Client: {{.Client.Version}} | Server: {{.Server.Version}}"
```

### Emergency Docker Access
If WSL Docker fails, use Windows Docker directly:
```powershell
# In Windows PowerShell
docker context use desktop-linux
docker ps
docker-compose -f "\\wsl$\Ubuntu-20.04\home\ilan\open-webui\docker-compose.yaml" up
```

### Working Configuration Backup
```bash
# Create backup of working configuration
echo "# Working Docker Configuration Backup - $(date)" > docker-config-backup.txt
echo "Socket link: $(ls -la /var/run/docker.sock)" >> docker-config-backup.txt
echo "Target socket: $(ls -la /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock)" >> docker-config-backup.txt
echo "Docker context: $(docker context show)" >> docker-config-backup.txt
echo "Docker version: $(docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}')" >> docker-config-backup.txt
echo "WSL config: $(cat /etc/wsl.conf | grep command)" >> docker-config-backup.txt

# Backup all contexts (both Windows and WSL)
echo "=== Context Analysis ===" >> docker-config-backup.txt
echo "WSL Contexts:" >> docker-config-backup.txt
docker context ls >> docker-config-backup.txt
echo "Active WSL Context: $(docker context show)" >> docker-config-backup.txt
echo "Windows Contexts (run in PowerShell):" >> docker-config-backup.txt
echo "# docker context ls" >> docker-config-backup.txt
echo "# docker context show" >> docker-config-backup.txt
```

---

## Document History
- **Created**: May 28, 2025
- **Updated**: May 28, 2025 - Added verified working paths and current configuration
- **Updated**: May 28, 2025 - Added comprehensive cross-platform Docker context analysis
- **Issue Resolved**: Docker Desktop WSL2 integration socket path and permissions
- **Context Analysis**: Documented redundant contexts across Windows and WSL environments
- **Environment**: Windows Docker Desktop v28.1.1 + WSL2 Ubuntu-20.04
- **Status**: ✅ RESOLVED - Docker and Docker Compose working correctly with verified paths

## Verified Working Configuration Summary
```
✅ Docker Desktop Source: /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock
✅ WSL Docker Endpoint:   /var/run/docker.sock → (symbolic link to source)
✅ WSL Docker Context:    wsl-docker (active)
✅ Windows Docker Context: desktop-linux (active)
✅ WSL Configuration:     /etc/wsl.conf (corrected boot command)
✅ Status:               Client 28.1.1 ↔ Server 28.1.1 (Connected)
✅ Context Redundancy:    Documented and analyzed (no conflicts)
```