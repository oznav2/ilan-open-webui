# AI Stack Documentation

## Table of Contents
- [Overview](#overview)
- [Layered Architecture](#layered-architecture)
- [Network Configuration](#network-configuration)
- [Volume Management](#volume-management)
- [Environment Configuration](#environment-configuration)
- [Service Health and Dependencies](#service-health-and-dependencies)
- [Hardware Resource Management](#hardware-resource-management)
- [Backup Strategy](#backup-strategy)
- [AI Model Infrastructure](#ai-model-infrastructure)
- [Content Processing Services](#content-processing-services)
- [Automation and Workflow Services](#automation-and-workflow-services)
- [Monitoring and Management](#monitoring-and-management)
- [Security Considerations](#security-considerations)
- [Service Interactions and Data Flow](#service-interactions-and-data-flow)
- [Port Mappings Reference](#port-mappings-reference)
- [Recommendations and Best Practices](#recommendations-and-best-practices)

## Overview

This document describes a comprehensive AI infrastructure stack deployed using Docker Compose. The stack provides a complete environment for working with AI models, including:

- Local and cloud-based AI model inference
- Retrieval Augmented Generation (RAG) capabilities
- Document processing and vector embeddings
- Workflow automation and orchestration
- Database management and persistence
- Comprehensive monitoring and backup solutions

The stack follows a layered architecture with clear dependencies between services, ensuring proper startup sequence and resource allocation. It leverages GPU acceleration for AI workloads and provides a comprehensive backup strategy for data protection.

## Layered Architecture

The stack is organized into logical layers, with each layer building upon the services provided by lower layers. This architecture ensures proper startup sequencing and dependency management.

### Layer 1: Core Infrastructure
- **postgres** - PostgreSQL database for application data
- **redis** - High-performance caching and pub/sub messaging
- **qdrant** - Vector database for AI embeddings

### Layer 2: Model Infrastructure
- **ollama** - Local large language model inference engine
- **litellm_db** - Database for LiteLLM service

### Layer 3: Primary Services
- **open-webui** - Modern web UI for interacting with language models
- **litellm** - API management for LLM services

### Layer 4: Content Processing
- **tika** - Apache Tika for extracting text from documents
- **playwright** - Headless browser for web scraping
- **pipelines** - Data processing workflows

### Layer 5: Automation and Data Management
- **n8n** - Workflow automation platform
- **n8n-import** - Imports predefined workflows and credentials
- **unstructured** - Extracts structured data from unstructured documents
- **linkwarden** - Bookmark and web content management
- **flowise** - Visual interface for creating AI flows

### Layer 6: Specialized Services
- **libretranslate** - Machine translation between languages
- **searxng** - Privacy-focused metasearch engine

### Layer 7: Monitoring and Management
- **prometheus** - Metrics collection and visualization
- **pgadmin** - PostgreSQL database management
- **qdrant-dashboard-proxy** - Web interface for Qdrant
- **glances** - Real-time system monitoring

### Layer 8: Backup Services
- **backup** - Duplicati backup for most services
- **qdrant-backup** - Dedicated backup for Qdrant vector database

## Network Configuration

The stack uses a custom bridge network called `open-webui` that connects all services:

```yaml
networks:
  open-webui:
    driver: bridge
```

This network configuration provides:

1. **Service Discovery**: Services can communicate using container names as hostnames
2. **Network Isolation**: Communication between containers is isolated from the host network
3. **Controlled Exposure**: Only necessary ports are exposed to the host
4. **Simplified References**: Services reference each other by name (e.g., `http://redis:6379`)

Most inter-service communication occurs within this network, while selected services are exposed to the host via port mappings for external access.

## Volume Management

The stack employs a comprehensive volume strategy to ensure data persistence and sharing:

### Named Volumes
```yaml
volumes:
  ollama:
  open-webui:
  pipelines:
  n8n_storage:
  postgres_storage:
  litellm_db:
  prometheus_data:
  qdrant_storage:
  flowise:
  libretranslate_api_keys:
  redis-data:
  linkwarden_data:
  pgadmin_data_new:
  unstructured_data:
  backup_config:
  qdrant_backup_config:
  qdrant_backups:
  db_dumps:
```

These Docker-managed volumes persist data between container restarts and rebuilds.

### Bind Mounts
Some services use bind mounts to map host directories:

```yaml
volumes:
  - /home/ilan/redis-data:/data  # Redis data
  - ./n8n/backup:/backup         # N8N workflows/credentials
  - ./db-dump.sh:/scripts/db-dump.sh:ro  # Backup scripts
```

### Volume Access Patterns

1. **Data Persistence**:
   ```yaml
   volumes:
     - postgres_storage:/var/lib/postgresql/data
   ```

2. **Configuration Sharing**:
   ```yaml
   volumes:
     - ./litellm-config.yaml:/app/config.yaml
   ```

3. **Read-Only Access** (for backup services):
   ```yaml
   volumes:
     - ollama:/source/ollama:ro
     - open-webui:/source/open-webui:ro
   ```

4. **Directory Mapping**:
   ```yaml
   volumes:
     - ./data/docs:/data/docs
   ```

The volume strategy ensures data persistence, proper backup access, and clear separation between configuration and application data.

## Environment Configuration

The stack uses a combination of environment configuration approaches:

### External .env File
Most services reference an external .env file:
```yaml
env_file:
  - /home/ilan/open-webui/.env
```

### In-line Environment Variables
Some services define variables directly:
```yaml
environment:
  - PORT=3001
  - FLOWISE_USERNAME=${FLOWISE_USERNAME:-}
  - FLOWISE_PASSWORD=${FLOWISE_PASSWORD:-}
```

### Variable Substitution with Defaults
The stack uses variable substitution with defaults extensively:
```yaml
environment:
  - POSTGRES_MULTIPLE_DATABASES=${LINKWARDEN_DB:-linkwarden},${N8N_DB:-n8n}
```

### Key Environment Variables

1. **Database Credentials**:
   ```
   POSTGRES_USER=root
   POSTGRES_PASSWORD=password
   POSTGRES_DB=n8n
   ```

2. **API Keys** (for various external services):
   ```
   OPENAI_API_KEY='sk-...'
   ANTHROPIC_API_KEY='sk-ant-...'
   ```

3. **Service Connection URLs**:
   ```
   OLLAMA_API_BASE_URL=http://ollama:11434/api
   REDIS_URL=redis://default:${REDIS_PASSWORD:-$REDIS_PASS}@redis:6379
   QDRANT_URI=http://qdrant:${QDRANT_PORT:-6333}
   ```

4. **AI Model Configuration**:
   ```
   OLLAMA_GPU_LAYERS=40
   OLLAMA_FLASH_ATTENTION=true
   RAG_EMBEDDING_MODEL='intfloat/multilingual-e5-large'
   ```

5. **Backup Configuration**:
   ```
   B2_ACCOUNT_ID=002219916dc5d760000000001
   B2_ACCOUNT_KEY=K002ZsmMZXmaL9NgE6OqkKbM6n0mDpU
   B2_BUCKET_NAME=ai-stack
   ```

This configuration approach centralizes settings in the .env file while allowing service-specific overrides and sensible defaults.

## Service Health and Dependencies

The stack implements a comprehensive health monitoring and dependency management system:

### Healthchecks

Most services include healthchecks appropriate to their function:

1. **Database Services**:
   ```yaml
   healthcheck:
     test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
     interval: 5s
     timeout: 5s
     retries: 5
     start_period: 10s
   ```

2. **Web Services**:
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
     interval: 30s
     timeout: 10s
     retries: 3
     start_period: 40s
   ```

3. **Application Services**:
   ```yaml
   healthcheck:
     test: ["CMD", "ollama", "ps"]
     interval: 15s
     timeout: 10s
     retries: 5
     start_period: 30s
   ```

### Dependencies

Dependencies are managed through:

1. **Explicit Dependencies**:
   ```yaml
   depends_on:
     postgres:
       condition: service_started
     redis:
       condition: service_started
   ```

2. **Layered Start Timing**:
   Services in higher layers have longer `start_period` values in their healthchecks to allow lower-layer services to initialize first.

This comprehensive health and dependency system ensures services start in the correct order and failed services are detected quickly.

## Hardware Resource Management

The stack includes sophisticated hardware resource management, particularly for GPU-accelerated services:

### GPU Access

Services that require GPU acceleration use Docker's GPU passthrough:

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

Services with GPU access include:
- **ollama** (LLM inference)
- **open-webui** (Web UI with potential GPU features)
- **pipelines** (Processing workflows)
- **libretranslate** (Translation service)

### CUDA Configuration

GPU-accelerated services include optimized CUDA settings:

```yaml
environment:
  NVIDIA_DRIVER_CAPABILITIES: compute,utility
  NVIDIA_VISIBLE_DEVICES: all
  OLLAMA_GPU_LAYERS: 40
  OLLAMA_FLASH_ATTENTION: true
  USE_CUDA: 'true'
  USE_CUDA_VER: "cu121"
```

### Resource Limits

Some services have explicit resource constraints:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 4G
    reservations:
      cpus: '0.5'
      memory: 2G
```

This resource management strategy ensures GPU resources are available to AI-intensive services while preventing any single service from consuming excessive resources.

## Backup Strategy

The stack implements a comprehensive backup strategy using Duplicati:

### Primary Backup Service

```yaml
backup:
  image: linuxserver/duplicati:latest
  environment:
    - CRON_EXPRESSION=0 3 */3 * *  # Every 3 days at 3 AM
    - DB_CRON_EXPRESSION=0 1 * * *  # Daily at 1 AM
    - CLI_ARGS=--webservice-password=oznav214 --backup-name="AI Stack Incremental Backup" --dbpath=/config/AISTACK.sqlite --backup-retention-policy=30D:1W,1W:1M --run-script-before=/scripts/db-dump.sh --run-script-after=/scripts/backup-notification.sh
  volumes:
    - backup_config:/config
    - ./db-dump.sh:/scripts/db-dump.sh:ro
    - ./backup-notification.sh:/scripts/backup-notification.sh:ro
    - ./backup-config.json:/config/duplicati-server-settings.json:ro
    - /home/ilan/redis-backup-direct.sh:/scripts/redis-backup-direct.sh:ro
    - ollama:/source/ollama:ro
    - open-webui:/source/open-webui:ro
    # Many more volume mappings...
```

### Qdrant-Specific Backup

```yaml
qdrant-backup:
  image: linuxserver/duplicati:latest
  environment:
    - CRON_EXPRESSION=0 4 */3 * *  # Every 3 days at 4 AM
    - CLI_ARGS=--webservice-password=oznav214 --backup-name="Qdrant Incremental Backup" --dbpath=/config/QDRANT.sqlite --backup-retention-policy=30D:1W,1W:1M --run-script-after=/scripts/backup-notification.sh
  volumes:
    - qdrant_storage:/source/qdrant_storage:ro
    # Other volume mappings...
```

### Backup Features

1. **Cloud Storage Integration**:
   Backups are stored in Backblaze B2 cloud storage:
   ```yaml
   environment:
     - B2_ACCOUNT_ID=${B2_APP_KEY_ID:-$B2_ACCOUNT_ID}
     - B2_ACCOUNT_KEY=${B2_APP_KEY:-$B2_ACCOUNT_KEY}
     - B2_BUCKET_NAME=${B2_BUCKET:-aistack}
   ```

2. **Database Dump Scripts**:
   The `db-dump.sh` script runs before backups to create consistent database dumps.

3. **Retention Policies**:
   ```
   --backup-retention-policy=30D:1W,1W:1M
   ```
   This keeps daily backups for 30 days and weekly backups for a month.

4. **Encryption**:
   ```
   SETTINGS_ENCRYPTION_KEY=oznav214
   ```
   Ensures backup data is encrypted.

5. **Notification Scripts**:
   ```
   --run-script-after=/scripts/backup-notification.sh
   ```
   Notifies upon backup completion.

This backup strategy ensures comprehensive data protection with regular, encrypted backups stored both locally and in cloud storage.

## AI Model Infrastructure

The AI capabilities of the stack are built around several key services:

### Ollama (Local Model Inference)

```yaml
ollama:
  image: ollama/ollama:latest
  environment:
    OLLAMA_HOST: 0.0.0.0
    OLLAMA_KEEP_ALIVE: 24h
    ENABLE_IMAGE_GENERATION: "True"
    OLLAMA_GPU_LAYERS: 40
    OLLAMA_FLASH_ATTENTION: true
    OLLAMA_NUM_PARALLEL: 2
    OLLAMA_BATCH_SIZE: 128
```

Ollama provides local inference for large language models with GPU acceleration. Key features include:
- Persistent model loading (`OLLAMA_KEEP_ALIVE: 24h`)
- Multimodal capabilities (`ENABLE_IMAGE_GENERATION: "True"`)
- GPU optimization (`OLLAMA_GPU_LAYERS: 40`, `OLLAMA_FLASH_ATTENTION: true`)
- Parallel processing (`OLLAMA_NUM_PARALLEL: 2`, `OLLAMA_BATCH_SIZE: 128`)

### Open-WebUI (User Interface)

```yaml
open-webui:
  build:
    context: /home/ilan/open-webui
    dockerfile: Dockerfile.git
    args:
      USE_EMBEDDING_MODEL: ${USE_EMBEDDING_MODEL:-sentence-transformers/all-MiniLM-L6-v2}
  environment:
    RAG_EMBEDDING_MODEL: "${USE_EMBEDDING_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
    OLLAMA_API_BASE_URL: ${OLLAMA_API_BASE_URL:-http://ollama:11434/api}
    QDRANT_URI: http://qdrant:${QDRANT_PORT:-6333}
    VECTOR_DB: qdrant
```

Open-WebUI provides the interface for interacting with AI models and manages RAG capabilities:
- Connection to Ollama for local inference
- Integration with external API providers
- Embedding model for vector generation
- Qdrant integration for vector storage

### LiteLLM (Model API Management)

```yaml
litellm:
  image: ghcr.io/berriai/litellm:main-latest
  volumes:
    - ./litellm-config.yaml:/app/config.yaml
  environment:
    - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY:-sk-proj-mLsKevnhckwOHtOz1QGRT3BlbkFJwG2mtRtiVlBDoI2DJxYg}
```

LiteLLM provides API management for language models:
- Routing to multiple model providers
- Logging and monitoring of API usage
- Key management and authentication
- Consistent API interface across providers

### Qdrant (Vector Database)

```yaml
qdrant:
  image: qdrant/qdrant
  environment:
    - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY:-$QDRANT_KEY}
    - QDRANT__SERVICE__ENABLE_API_KEY_AUTHORIZATION=true
```

Qdrant stores vector embeddings for RAG capabilities:
- Vector similarity search
- Persistent storage of embeddings
- API key authentication
- Integration with Open-WebUI

This AI infrastructure supports both local and cloud model access, with vector storage for enhanced capabilities through RAG.

## Content Processing Services

The stack includes specialized services for content extraction and processing:

### Apache Tika (Document Parsing)

```yaml
tika:
  image: apache/tika:latest-full
  ports:
    - 9998:9998
```

Tika extracts text and metadata from various document formats:
- PDF processing
- Office document extraction
- Image text extraction
- Metadata parsing

### Playwright (Web Scraping)

```yaml
playwright:
  image: mcr.microsoft.com/playwright:v1.49.1-noble
  command: npx -y playwright@1.49.1 run-server --port 3004 --host 0.0.0.0
```

Playwright provides headless browser capabilities:
- Web page rendering
- JavaScript execution
- Content extraction
- Dynamic site handling

### Unstructured (Complex Document Processing)

```yaml
unstructured:
  image: quay.io/unstructured-io/unstructured-api:latest
  environment:
    - UNSTRUCTURED_API_KEY=${UNSTRUCTURED_API_KEY:-$UNSTRUCTURED_KEY}
```

Unstructured extracts content from complex documents:
- Table extraction
- Layout-aware parsing
- Multi-format support
- Element classification

These services form a comprehensive content processing pipeline:
1. Document/URL input to Open-WebUI
2. Content extraction via appropriate service
3. Text processing and chunking
4. Embedding generation and storage in Qdrant
5. Retrieval for RAG applications

## Automation and Workflow Services

The stack includes powerful automation tools:

### N8N (Workflow Automation)

```yaml
n8n:
  image: n8nio/n8n:latest
  environment:
    - DB_TYPE=postgresdb
    - DB_POSTGRESDB_DATABASE=${N8N_DB:-n8n}
    - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-super-secret-key}
    - QUEUE_BULL_REDIS_HOST=redis
```

N8N provides comprehensive workflow automation:
- Visual workflow editor
- Trigger-based automation
- Integration with hundreds of services
- Scheduling and event handling

The stack also includes an N8N importer:
```yaml
n8n-import:
  command:
    - "sleep 10 && n8n import:credentials --separate --input=/backup/credentials && n8n import:workflow --separate --input=/backup/workflows"
```

### Flowise (Visual AI Flow Creation)

```yaml
flowise:
  image: flowiseai/flowise
  environment:
    - PORT=3001
    - FLOWISE_USERNAME=${FLOWISE_USERNAME:-}
    - FLOWISE_PASSWORD=${FLOWISE_PASSWORD:-}
```

Flowise provides visual creation of AI-specific flows:
- Visual AI component wiring
- LLM chain creation
- API exposures
- AI agent design

These automation tools enable:
- Scheduled data processing
- Event-based workflows
- AI task orchestration
- System maintenance automation
- Cross-service coordination

## Monitoring and Management

The stack includes comprehensive monitoring and management tools:

### Prometheus (Metrics Collection)

```yaml
prometheus:
  image: prom/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--storage.tsdb.retention.time=15d'
```

Prometheus collects and stores metrics with 15-day retention.

### PGAdmin (PostgreSQL Management)

```yaml
pgadmin:
  image: dpage/pgadmin4:latest
  environment:
    - PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL:-ilan@mac.com}
    - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD:-oznav214}
```

PGAdmin provides database management with preconfigured server connections.

### Qdrant Dashboard (Vector DB Management)

```yaml
qdrant-dashboard-proxy:
  image: nginx:alpine
  command: >
    /bin/sh -c "echo 'server { ... }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
```

Provides web access to the Qdrant dashboard through an Nginx proxy.

### Glances (System Monitoring)

```yaml
glances:
  image: nicolargo/glances:latest
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /:/rootfs:ro
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
  pid: host
```

Glances provides real-time system monitoring with:
- Host CPU, memory, disk, network metrics
- Docker container stats
- Process monitoring
- Resource usage visualization

These tools provide comprehensive visibility into the stack's operation and performance.

## Security Considerations

The stack implements several security measures:

### Authentication and API Keys

Multiple services use API key authentication:
```yaml
environment:
  - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY:-$QDRANT_KEY}
  - QDRANT__SERVICE__ENABLE_API_KEY_AUTHORIZATION=true
```

```yaml
environment:
  - UNSTRUCTURED_API_KEY=${UNSTRUCTURED_API_KEY:-$UNSTRUCTURED_KEY}
```

### Database Credentials

Databases use username/password authentication:
```yaml
environment:
  - POSTGRES_USER=${POSTGRES_USER}
  - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
```

### Encryption Keys

Sensitive data is encrypted:
```yaml
environment:
  - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-super-secret-key}
  - SETTINGS_ENCRYPTION_KEY=oznav214
```

### Network Isolation

The dedicated `open-webui` network isolates inter-service communication.

### Container Capabilities

Some services limit container capabilities:
```yaml
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
  - DAC_OVERRIDE
```

### Read-Only Mounts

Backup services use read-only mounts:
```yaml
volumes:
  - ollama:/source/ollama:ro
```

The security approach primarily relies on network isolation, basic authentication, and encryption for sensitive data. However, there are areas for improvement:
- API keys are stored in plain text in the .env file
- Some services use default or simple passwords
- Internal communication lacks TLS/SSL
- CORS settings are permissive (`CORS_ALLOW_ORIGIN="*"`)

## Service Interactions and Data Flow

The stack features several key interaction patterns:

### AI Model Serving Flow
- User → Open-WebUI → Ollama for local model inference
- User → Open-WebUI → LiteLLM → External APIs (OpenAI, Anthropic)

### RAG (Retrieval Augmented Generation) Flow
- Document → Open-WebUI → Tika/Unstructured → Text Extraction
- Text → Open-WebUI → Embedding Model → Vector Embedding
- Vectors → Qdrant for storage
- Query → Open-WebUI → Similar Vectors from Qdrant → Enhanced Response

### Web Content Processing
- URL → Open-WebUI → Playwright → Web Content → Processing → Qdrant

### Automation Workflows
- Trigger → N8N → Orchestration → Multiple Services
- Visual Flow → Flowise → AI Components → Results

### Database Dependencies
- PostgreSQL ← N8N, Linkwarden
- LiteLLM DB ← LiteLLM
- Redis ← Multiple Services (messaging, caching)
- Qdrant ← Open-WebUI (vector storage)

### Monitoring Flow
- Services → Prometheus → Metrics Storage
- User → Monitoring UIs (Glances, PGAdmin, Qdrant Dashboard)

### Backup Flow
- Multiple Volumes → Duplicati → Backblaze B2 Cloud Storage
- Database Dumps → db-dump.sh → Backup Volumes

This interconnected architecture demonstrates how the services work together to provide a comprehensive AI stack with data persistence, processing, and automation capabilities.

## Port Mappings Reference

| Service | Port Mapping | Purpose |
|---------|--------------|---------|
| postgres | 5431:5432 | PostgreSQL database access |
| redis | 6379:6379 | Redis cache and messaging |
| qdrant | 6333:6333 | Vector database |
| ollama | 11434:11434 | LLM inference API |
| litellm_db | 5434:5432 | LiteLLM database |
| open-webui | 8080:8080 | Main user interface |
| litellm | 4001:4000 | LLM API management |
| tika | 9998:9998 | Document text extraction |
| playwright | 3004:3004 | Headless browser |
| pipelines | 9099:9099 | Processing workflows |
| n8n | 5678:5678 | Workflow automation |
| unstructured | 8000:8000 | Structured data extraction |
| linkwarden | 3000:3000 | Bookmark management |
| flowise | 3001:3001 | Visual flow creation |
| libretranslate | 5000:5000 | Machine translation |
| searxng | 8083:8080 | Metasearch engine |
| prometheus | 9090:9090 | Metrics collection |
| pgadmin | 15432:80 | Database management |
| qdrant-dashboard | 8090:80 | Vector DB management |
| glances | 61208:61208 | System monitoring |
| backup | 8200:8200 | Main backup UI |
| qdrant-backup | 8201:8200 | Qdrant backup UI |