# N8N Service Documentation in AI Stack

## Table of Contents
- [Overview](#overview)
- [Service Architecture](#service-architecture)
- [Network Configuration](#network-configuration)
- [Volume Management](#volume-management)
- [Environment Configuration](#environment-configuration)
- [Database Integration](#database-integration)
- [Redis Integration](#redis-integration)
- [Security Configuration](#security-configuration)
- [External Access and API](#external-access-and-api)
- [Service Interactions](#service-interactions)
- [Workflow Import Process](#workflow-import-process)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)
- [Recommendations](#recommendations)

## Overview

N8N is a powerful workflow automation platform deployed as part of the AI stack. It provides a visual interface for creating workflows that integrate various services, APIs, and data sources. This documentation covers the configuration and integration of N8N within the larger AI infrastructure stack.

In this implementation, N8N serves as a central automation hub that can orchestrate tasks across multiple services, process data, and trigger actions based on various events. The service is positioned in Layer 5 (Automation and Data Management) of the stack's architecture, highlighting its role in providing workflow automation capabilities to the entire system.

## Service Architecture

### Basic Configuration

```yaml
n8n:
  image: n8nio/n8n:latest
  pull_policy: always
  networks: 
    - open-webui
  container_name: n8n
  tty: true
  restart: unless-stopped
  ports:
    - 5678:5678
  expose:
    - 5678
```

The N8N service uses the official `n8nio/n8n:latest` Docker image, which provides the most recent stable version of N8N. The service is configured to always restart unless explicitly stopped, ensuring high availability for automated workflows.

### Positioning in Stack

N8N is positioned in Layer 5 of the stack architecture, which includes:

- **Layer 5: Automation and Data Management**
  - n8n: Workflow automation platform
  - n8n-import: Imports predefined workflows and credentials
  - unstructured: Extracts structured data from unstructured documents
  - linkwarden: Bookmark and web content management
  - flowise: Visual interface for creating AI flows

This positioning ensures N8N starts after the core infrastructure layers (databases, model infrastructure, primary services, and content processing) are operational, allowing it to interact with these services in its workflows.

## Network Configuration

N8N is connected to the `open-webui` bridge network:

```yaml
networks: 
  - open-webui
```

This custom bridge network connects all services in the stack, enabling N8N to communicate with other services using container names as hostnames (e.g., `postgres`, `redis`, `ollama`).

### Port Mapping

```yaml
ports:
  - 5678:5678
expose:
  - 5678
```

Port 5678 is:
- Exposed within the Docker network for inter-container communication
- Mapped to port 5678 on the host, allowing external access to the N8N web interface

### Dependencies

```yaml
depends_on:
  postgres:
    condition: service_started
  redis:
    condition: service_started
  ollama:
    condition: service_healthy
```

The `depends_on` directive ensures N8N starts only after its dependencies are ready:
- PostgreSQL for database storage
- Redis for queue management
- Ollama for LLM capabilities

An additional explicit link to PostgreSQL is defined:

```yaml
links:
  - postgres
```

## Volume Management

N8N uses a named Docker volume for data persistence:

```yaml
volumes:
  - n8n_storage:/home/node/.n8n
```

The volume `n8n_storage` maps to `/home/node/.n8n` inside the container, storing:
- Workflow definitions
- Execution data
- Credentials (encrypted)
- Configuration settings
- Binary data (when filesystem storage is used)

This persistent storage ensures that workflows, credentials, and other data are preserved across container restarts and updates.

### Import Service Volume

The companion n8n-import service has its own volume mapping:

```yaml
volumes:
  - ./n8n/backup:/backup
```

This maps a host directory `./n8n/backup` to the `/backup` directory in the container, containing the workflows and credentials to be imported during initialization.

## Environment Configuration

N8N's behavior is extensively customized through environment variables, which can be grouped into several categories:

### Core Configuration

```yaml
env_file:
  - /home/ilan/open-webui/.env
```

N8N loads environment variables from an external `.env` file in addition to those defined in the docker-compose file.

### Database Configuration

```yaml
- DB_TYPE=postgresdb
- DB_POSTGRESDB_HOST=postgres
- DB_POSTGRESDB_PORT=5432
- DB_POSTGRESDB_USER=${POSTGRES_USER}
- DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
- DB_POSTGRESDB_DATABASE=${N8N_DB:-n8n}
```

These variables configure N8N to use PostgreSQL for data storage, with connection details referencing variables from the `.env` file.

### Queue Configuration

```yaml
- QUEUE_BULL_REDIS_HOST=redis
- QUEUE_BULL_REDIS_PORT=6379
- QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD:-$REDIS_PASS}
```

N8N uses Redis for queue management, enhancing workflow execution reliability and enabling distributed processing.

### Security Settings

```yaml
- N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-super-secret-key}
- N8N_USER_MANAGEMENT_JWT_SECRET=even-more-secret-12345
- N8N_SKIP_CREDENTIALS_DECRYPTION_CHECK_ON_STARTUP=true
- N8N_USER_MANAGEMENT_DISABLED=true
```

These settings configure encryption, authentication, and user management.

### API and Webhook Settings

```yaml
- N8N_PUBLIC_API_DISABLED=false
- N8N_PUBLIC_API_ALLOW_VERBS_WITH_BODY=true
- N8N_WEBHOOK_ENABLED=true
- N8N_WEBHOOK_ALLOW_INSECURE=true
- N8N_HOST=n8n.ilanel.co.il
- N8N_PROTOCOL=https
- N8N_PORT=5678
- N8N_WEBHOOK_URL=https://n8n.ilanel.co.il
- N8N_EDITOR_URL=https://n8n.ilanel.co.il
- WEBHOOK_URL=https://n8n.ilanel.co.il
```

These configure the N8N API, webhook functionality, and external URLs.

### Resource and Performance Settings

```yaml
- NODE_OPTIONS=--max-old-space-size=12288
- N8N_TIMEOUT_MAX_EXECUTION_TIME=3600
```

These control resource allocation (12GB memory for Node.js) and execution limits (1 hour maximum).

### Feature Flags

```yaml
- N8N_DIAGNOSTICS_ENABLED=false
- N8N_PERSONALIZATION_ENABLED=false
- N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
- N8N_HIRING_BANNER_ENABLED=false
- N8N_RUNNERS_ENABLED=true
- N8N_COMMUNITY_PACKAGES_ENABLED=true
- N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
```

These enable or disable specific N8N features.

### Logging and Monitoring

```yaml
- LOG_LEVEL=debug
- N8N_LOG_LEVEL=verbose
- N8N_METRICS=true
- N8N_METRICS_PREFIX=n8n_
```

These control logging verbosity and enable metrics collection for monitoring.

### Enterprise Features

```yaml
- N8N_LICENSE_CERT_KEY=
- MOCK_LICENSE_ENFORCER=true
- N8N_DISABLE_ENTERPRISE_FEATURES=true
- N8N_SKIP_LICENSE_VALIDATION=true
```

These settings disable enterprise features and license validation.

### CORS Settings

```yaml
- N8N_CORS_ALLOW_ORIGIN="*"
- N8N_CORS_ALLOW_ORIGIN_WHITELIST="*"
- N8N_CORS_ALLOW_ORIGIN_WHITELIST_REGEX="*"
```

These configure cross-origin resource sharing, currently set to allow all origins.

### Additional Settings

```yaml
- NODEJS_PREFER_IPV4=true
- "N8N_LISTEN_ADDRESS=::"
- N8N_LISTEN_PORT=5678
- GENERIC_TIMEZONE=UTC
- TZ=Asia/Jerusalem
- NODE_ENV=production
- N8N_DEFAULT_BINARY_DATA_MODE=filesystem
- "NODE_FUNCTION_ALLOW_BUILTIN=*"
```

These configure network behavior, timezone, execution mode, and other operational settings.

## Database Integration

N8N relies on PostgreSQL for data storage:

```yaml
- DB_TYPE=postgresdb
- DB_POSTGRESDB_HOST=postgres
- DB_POSTGRESDB_PORT=5432
- DB_POSTGRESDB_USER=${POSTGRES_USER}
- DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
- DB_POSTGRESDB_DATABASE=${N8N_DB:-n8n}
```

From the `.env` file:
```
POSTGRES_USER=root
POSTGRES_PASSWORD=password
POSTGRES_DB=n8n
N8N_DB=n8n
```

This configuration ensures N8N stores its data in a dedicated PostgreSQL database, including:
- Workflow definitions
- Execution history
- Encrypted credentials
- User data (when user management is enabled)
- Settings and configuration

The database service is configured with the following parameters:
- Host: postgres (container name)
- Port: 5432 (standard PostgreSQL port)
- Database: n8n (defined in .env as N8N_DB)
- User: root (defined in .env as POSTGRES_USER)
- Password: password (defined in .env as POSTGRES_PASSWORD)

## Redis Integration

N8N uses Redis for queue management and execution handling:

```yaml
- QUEUE_BULL_REDIS_HOST=redis
- QUEUE_BULL_REDIS_PORT=6379
- QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD:-$REDIS_PASS}
```

From the `.env` file:
```
REDIS_PASSWORD=password
REDIS_PASS=password
REDIS_URL=redis://default:${REDIS_PASSWORD:-$REDIS_PASS}@redis:6379
REDIS_HOST=redis
REDIS_PORT=6379
```

Redis provides:
- Queue management for workflow execution
- Distributed processing capabilities
- Improved performance for workflow execution
- Reliability for execution data

The Redis integration is particularly important when running multiple N8N instances or processing large numbers of workflows.

## Security Configuration

N8N's security configuration includes:

### Encryption

```yaml
- N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-super-secret-key}
```

From `.env`:
```
N8N_ENCRYPTION_KEY=super-secret-key
```

This key is used to encrypt sensitive data like credentials and is critical for security.

### Authentication

```yaml
- N8N_USER_MANAGEMENT_JWT_SECRET=even-more-secret-12345
- N8N_USER_MANAGEMENT_DISABLED=true
```

User management is currently disabled, which means N8N is accessible without authentication. This is a potential security risk in production environments.

### API Security

```yaml
- N8N_PUBLIC_API_DISABLED=false
- N8N_WEBHOOK_ALLOW_INSECURE=true
```

The public API is enabled, and insecure webhooks are allowed, which should be carefully considered in production environments.

### CORS Configuration

```yaml
- N8N_CORS_ALLOW_ORIGIN="*"
- N8N_CORS_ALLOW_ORIGIN_WHITELIST="*"
- N8N_CORS_ALLOW_ORIGIN_WHITELIST_REGEX="*"
```

These permissive CORS settings allow requests from any origin, which may present security risks.

## External Access and API

N8N is configured for external access:

```yaml
- N8N_HOST=n8n.ilanel.co.il
- N8N_PROTOCOL=https
- N8N_PORT=5678
- N8N_WEBHOOK_URL=https://n8n.ilanel.co.il
- N8N_EDITOR_URL=https://n8n.ilanel.co.il
- WEBHOOK_URL=https://n8n.ilanel.co.il
- VIRTUAL_HOST=n8n.ilanel.co.il
- LETSENCRYPT_HOST=n8n.ilanel.co.il
```

These settings indicate N8N is accessed via:
- Domain: n8n.ilanel.co.il
- Protocol: HTTPS
- Port: 5678

The presence of `VIRTUAL_HOST` and `LETSENCRYPT_HOST` variables suggests a reverse proxy (likely Traefik or Nginx with Let's Encrypt) handles SSL termination and domain routing.

### API Configuration

```yaml
- N8N_PUBLIC_API_DISABLED=false
- N8N_PUBLIC_API_ALLOW_VERBS_WITH_BODY=true
```

The public API is enabled, allowing external systems to interact with N8N programmatically.

## Service Interactions

N8N interacts with several other services in the stack:

### PostgreSQL

Used for persistent storage of workflows, credentials, and execution data.

### Redis

Used for queue management and workflow execution.

### Ollama

```yaml
- OLLAMA_HOST=http://ollama:11434
```

This connection allows N8N workflows to leverage Ollama's LLM capabilities.

### N8N-Import Service

```yaml
n8n-import:
  # ...
  depends_on:
    n8n:
      condition: service_started
  # ...
  command:
    - "-c"
    - "sleep 10 && n8n import:credentials --separate --input=/backup/credentials && n8n import:workflow --separate --input=/backup/workflows"
```

This companion service imports predefined workflows and credentials during stack initialization.

## Workflow Import Process

The stack includes a dedicated service for importing workflows and credentials:

```yaml
n8n-import:
  image: n8nio/n8n:latest
  networks: 
    - open-webui
  container_name: n8n-import
  env_file:
    - /home/ilan/open-webui/.env
  environment:
    - DB_TYPE=postgresdb
    - DB_POSTGRESDB_HOST=postgres
    - DB_POSTGRESDB_PORT=5432
    - DB_POSTGRESDB_USER=${POSTGRES_USER}
    - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    - DB_POSTGRESDB_DATABASE=${N8N_DB:-n8n}
    - N8N_DIAGNOSTICS_ENABLED=false
    - N8N_PERSONALIZATION_ENABLED=false
    - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-super-secret-key}
    - N8N_USER_MANAGEMENT_JWT_SECRET=even-more-secret-12345
    - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
    - EXECUTIONS_MODE=queue
    - QUEUE_BULL_REDIS_HOST=redis
    - QUEUE_BULL_REDIS_PORT=6379
    - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD:-$REDIS_PASS}
  entrypoint: /bin/sh
  command:
    - "-c"
    - "sleep 10 && n8n import:credentials --separate --input=/backup/credentials && n8n import:workflow --separate --input=/backup/workflows"
  volumes:
    - ./n8n/backup:/backup
  depends_on:
    n8n:
      condition: service_started
    postgres:
      condition: service_started
    redis:
      condition: service_started
```

This service:
1. Waits for the main N8N service to start
2. Sleeps for 10 seconds to ensure N8N is fully initialized
3. Imports credentials from the `/backup/credentials` directory
4. Imports workflows from the `/backup/workflows` directory
5. Uses the `--separate` flag to maintain individual files for each workflow/credential

This process ensures that predefined workflows and credentials are automatically loaded into N8N when the stack is deployed, facilitating easier setup and consistent configuration.

## Performance Tuning

Several settings optimize N8N's performance:

```yaml
- NODE_OPTIONS=--max-old-space-size=12288
- N8N_TIMEOUT_MAX_EXECUTION_TIME=3600
- N8N_RUNNERS_ENABLED=true
```

These settings:
- Allocate 12GB of memory to the Node.js process
- Set maximum workflow execution time to 1 hour
- Enable workflow runners, which improve execution performance

The integration with Redis for queue management also enhances performance by enabling:
- Distributed workflow execution
- Better handling of concurrent workflows
- Improved reliability for long-running workflows

## Healthcheck Configuration

N8N includes a healthcheck configuration:

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 50s
```

This healthcheck:
- Checks the `/healthz` endpoint to verify N8N is operational
- Runs every 30 seconds
- Times out after 10 seconds
- Allows 3 retries before marking the service as unhealthy
- Gives N8N 50 seconds to start up before beginning health checks

The relatively long `start_period` acknowledges that N8N takes some time to initialize fully.

## Troubleshooting

Common issues and troubleshooting approaches for the N8N service:

### Database Connection Issues

If N8N fails to connect to the database:
1. Verify PostgreSQL service is running: `docker ps | grep postgres`
2. Check database credentials in `.env` file match docker-compose settings
3. Ensure the N8N database exists: `docker exec -it postgres psql -U root -c '\l'`
4. Check N8N logs: `docker logs n8n`

### Redis Connection Issues

If N8N can't connect to Redis:
1. Verify Redis service is running: `docker ps | grep redis`
2. Check Redis password in `.env` file matches docker-compose settings
3. Test Redis connection: `docker exec -it redis redis-cli -a password ping`
4. Check N8N logs: `docker logs n8n`

### Workflow Import Failures

If workflows aren't imported correctly:
1. Check n8n-import service logs: `docker logs n8n-import`
2. Verify the backup directory structure: `ls -la ./n8n/backup/`
3. Ensure files are in the correct format
4. Check that the encryption key in n8n-import matches the main n8n service

### Webhook Issues

If webhooks aren't working:
1. Verify the domain and port configuration
2. Check that the reverse proxy is correctly configured
3. Test webhook connectivity
4. Verify N8N's webhook settings: `docker exec -it n8n n8n webhook:list`
