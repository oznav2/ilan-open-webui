#!/bin/bash
# Script to dump PostgreSQL databases before backup

# Make directory for dumps if it doesn't exist
mkdir -p /source/db_dumps

# Timestamp for the dump files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Dump main PostgreSQL database
pg_dump -h postgres -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} -F c -f /source/db_dumps/postgres_${TIMESTAMP}.dump

# Dump additional databases if they exist
pg_dump -h postgres -U ${POSTGRES_USER:-postgres} -d ${LINKWARDEN_DB:-linkwarden} -F c -f /source/db_dumps/linkwarden_${TIMESTAMP}.dump
pg_dump -h postgres -U ${POSTGRES_USER:-postgres} -d ${N8N_DB:-n8n} -F c -f /source/db_dumps/n8n_${TIMESTAMP}.dump
pg_dump -h litellm_db -U ${LITELLM_POSTGRES_USER:-postgres} -d ${LITELLM_POSTGRES_DATABASE:-postgres} -F c -f /source/db_dumps/litellm_${TIMESTAMP}.dump

# Clean up older dumps (keep last 5)
cd /source/db_dumps
ls -t postgres_*.dump | tail -n +6 | xargs -r rm
ls -t linkwarden_*.dump | tail -n +6 | xargs -r rm
ls -t n8n_*.dump | tail -n +6 | xargs -r rm
ls -t litellm_*.dump | tail -n +6 | xargs -r rm

echo "Database dumps completed at $(date)"
exit 0