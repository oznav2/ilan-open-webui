#!/bin/bash
set -e

# Create a logs directory
LOGS_DIR="./supabase_logs"
mkdir -p $LOGS_DIR

# Function to clean up all containers and temp files
cleanup() {
  echo "Cleaning up all services and resources..."
  docker compose -f docker-compose-ilan-stack.yaml down --volumes
  docker volume ls | grep -q open-webui_supabase_db_data && docker volume rm open-webui_supabase_db_data || true
  docker volume ls | grep -q open-webui_db-config && docker volume rm open-webui_db-config || true
  echo "Cleanup complete."
}

# Function to check service health and capture logs with error detection
check_service() {
  local service_name=$1
  local container_name=$2
  local wait_time=${3:-10}
  local max_retries=${4:-3}
  local retry_count=0
  local critical=${5:-false}

  echo "============================================"
  echo "   Starting $service_name service"
  echo "============================================"
  docker compose -f docker-compose-ilan-stack.yaml up -d $service_name 2>&1 | tee -a "$LOGS_DIR/startup.log"
  
  echo "Waiting $wait_time seconds for $service_name to initialize..."
  sleep $wait_time
  
  # Start capturing logs in the background
  docker logs $container_name -f > "$LOGS_DIR/${container_name}.log" 2>&1 &
  local log_pid=$!
  
  # Check if service is running properly
  echo "Checking $service_name health..."
  while ! docker ps | grep $container_name | grep -q "Up"; do
    retry_count=$((retry_count+1))
    if [ $retry_count -ge $max_retries ]; then
      echo "❌ ERROR: $service_name failed to start properly after $max_retries attempts."
      echo "Last 20 lines of logs for debugging:"
      docker logs --tail 20 $container_name
      echo "Full logs saved to $LOGS_DIR/${container_name}.log"
      kill $log_pid 2>/dev/null || true
      
      # Provide specific guidance based on the service
      case $container_name in
        supabase-db)
          echo "💡 SUGGESTIONS FOR DATABASE ISSUES:"
          echo "  - Check PostgreSQL port availability (5432/5433)"
          echo "  - Verify database credentials in supabase.env"
          echo "  - Ensure no other PostgreSQL instance is running"
          ;;
        supabase-pooler)
          echo "💡 SUGGESTIONS FOR POOLER ISSUES:"
          echo "  - Check for database migration errors"
          echo "  - Verify connection to database is working"
          echo "  - Try increasing the pool size in supabase.env"
          echo "  - Consider clearing the pooler schema: docker exec supabase-db psql -U postgres -c 'DROP SCHEMA IF EXISTS pooler CASCADE;'"
          ;;
        supabase-auth)
          echo "💡 SUGGESTIONS FOR AUTH ISSUES:"
          echo "  - Check JWT secrets and keys in supabase.env"
          echo "  - Verify ENABLE_ANONYMOUS_USERS is set to true or false (not empty string)"
          echo "  - Check database role 'supabase_auth_admin' exists"
          ;;
        supabase-analytics)
          echo "💡 SUGGESTIONS FOR ANALYTICS ISSUES:"
          echo "  - Check LOGFLARE_API_KEY is properly set"
          echo "  - Verify _supabase database exists with _analytics schema"
          echo "  - Check connection to database from analytics container"
          ;;
        realtime-dev.supabase-realtime)
          echo "💡 SUGGESTIONS FOR REALTIME ISSUES:"
          echo "  - Check realtime SQL schema in database"
          echo "  - Verify JWT configuration"
          echo "  - Check network connectivity to database"
          ;;
        *)
          echo "💡 GENERAL TROUBLESHOOTING:"
          echo "  - Check for connection refused errors in logs"
          echo "  - Verify network connectivity between containers"
          echo "  - Check environment variables are set correctly"
          ;;
      esac
      
      # Critical services should stop the script when they fail
      if [ "$critical" = "true" ]; then
        echo "Critical service $service_name failed to start. Stopping deployment."
        cleanup
        exit 1
      else
        echo "Non-critical service $service_name failed to start. Continuing with other services."
        return 1
      fi
    fi
    echo "WARNING: $service_name not healthy yet. Waiting another $wait_time seconds... (Attempt $retry_count/$max_retries)"
    sleep $wait_time
  done
  
  # Service is running, but let's check for common errors in logs
  echo "Scanning $service_name logs for critical errors..."
  sleep 3 # Give a few seconds for logs to be written
  
  # Check for critical errors
  local has_critical_errors=false
  
  # Look for specific errors based on the service
  case $container_name in
    supabase-pooler)
      if grep -q "deadlock while migrating" "$LOGS_DIR/${container_name}.log" || \
         grep -q "connection not available" "$LOGS_DIR/${container_name}.log" || \
         grep -q "DBConnection.ConnectionError" "$LOGS_DIR/${container_name}.log"; then
        echo "❌ CRITICAL ERROR: Database pooler has connection or migration errors."
        grep -n "deadlock\|connection not available\|DBConnection.ConnectionError" "$LOGS_DIR/${container_name}.log" | head -n 5
        has_critical_errors=true
      fi
      ;;
    supabase-auth)
      if grep -q "Failed to load configuration" "$LOGS_DIR/${container_name}.log" || \
         grep -q "couldn't start a new transaction" "$LOGS_DIR/${container_name}.log" || \
         grep -q "converting '' to type bool" "$LOGS_DIR/${container_name}.log"; then
        echo "❌ CRITICAL ERROR: Auth service has configuration or connection errors."
        grep -n "Failed to load configuration\|couldn't start a new transaction\|converting '' to type bool" "$LOGS_DIR/${container_name}.log" | head -n 5
        has_critical_errors=true
      fi
      ;;
    supabase-analytics)
      if grep -q "connection to node logflare-db failed" "$LOGS_DIR/${container_name}.log" || \
         grep -q "couldn't start a new transaction" "$LOGS_DIR/${container_name}.log"; then
        echo "❌ CRITICAL ERROR: Analytics service has connection errors."
        grep -n "connection to node\|couldn't start a new transaction" "$LOGS_DIR/${container_name}.log" | head -n 5
        has_critical_errors=true
      fi
      ;;
    realtime-dev.supabase-realtime)
      if grep -q "failed to connect" "$LOGS_DIR/${container_name}.log"; then
        echo "❌ CRITICAL ERROR: Realtime service has connection errors."
        grep -n "failed to connect" "$LOGS_DIR/${container_name}.log" | head -n 5
        has_critical_errors=true
      fi
      ;;
    supabase-storage)
      if grep -q "ENOTFOUND" "$LOGS_DIR/${container_name}.log" || \
         grep -q "is undefined" "$LOGS_DIR/${container_name}.log"; then
        echo "❌ CRITICAL ERROR: Storage service has DNS or configuration errors."
        grep -n "ENOTFOUND\|is undefined" "$LOGS_DIR/${container_name}.log" | head -n 5
        has_critical_errors=true
      fi
      ;;
  esac
  
  # Generic error checks for all services
  if grep -q "fatal error" "$LOGS_DIR/${container_name}.log" || \
     grep -q "exited with code [1-9]" "$LOGS_DIR/${container_name}.log" || \
     grep -q "panic:" "$LOGS_DIR/${container_name}.log"; then
    echo "❌ CRITICAL ERROR: Service $service_name has fatal errors."
    grep -n "fatal error\|exited with code [1-9]\|panic:" "$LOGS_DIR/${container_name}.log" | head -n 5
    has_critical_errors=true
  fi
  
  # If critical errors are found and the service is marked critical, stop deployment
  if [ "$has_critical_errors" = "true" ] && [ "$critical" = "true" ]; then
    echo "Critical service $service_name has errors. Stopping deployment."
    kill $log_pid 2>/dev/null || true
    cleanup
    exit 1
  elif [ "$has_critical_errors" = "true" ]; then
    echo "Service $service_name has errors but will continue as it's not marked critical."
  else
    echo "✅ $service_name started successfully with no critical errors detected."
  fi
  
  kill $log_pid 2>/dev/null || true
  return 0
}

# Function to check for common errors in logs
scan_logs_for_errors() {
  local service_name=$1
  local log_file="$LOGS_DIR/${service_name}.log"
  
  if [ -f "$log_file" ]; then
    echo "Scanning $service_name logs for common errors..."
    
    # Connection refused errors
    if grep -q "connection refused" "$log_file"; then
      echo "⚠️ $service_name has connection refused errors. Network issue detected."
    fi
    
    # Authentication failures
    if grep -q "authentication failed" "$log_file"; then
      echo "⚠️ $service_name has authentication failures. Check credentials."
    fi
    
    # Missing environment variables
    if grep -q "undefined" "$log_file" || grep -q "is not defined" "$log_file"; then
      echo "⚠️ $service_name has undefined variables. Check environment configuration."
    fi
    
    # Database migration errors
    if grep -q "migration" "$log_file" && grep -q "error" "$log_file"; then
      echo "⚠️ $service_name has database migration errors."
    fi
  fi
}

echo "============================================"
echo "   Supabase Stack Initialization Script"
echo "============================================"
echo "Logs will be saved to $LOGS_DIR"

# Clear old logs
rm -rf $LOGS_DIR/*

# Load environment variables
export $(grep -v '^#' supabase.env | xargs)

# 1. Stop any running Supabase services and clean volumes
echo "Stopping existing Supabase services..."
docker compose -f docker-compose-ilan-stack.yaml down supabase_db supabase_studio supabase_kong supabase_auth supabase_rest supabase_realtime supabase_storage supabase_meta supabase_analytics supabase_vector supabase_edge_functions supabase_imgproxy supabase_pooler 2>&1 | tee -a "$LOGS_DIR/shutdown.log"

# Clean the volume to ensure a fresh start - only if they exist
echo "Cleaning volumes if they exist..."
docker volume ls | grep -q open-webui_supabase_db_data && docker volume rm open-webui_supabase_db_data || echo "Volume open-webui_supabase_db_data does not exist, skipping."
docker volume ls | grep -q open-webui_db-config && docker volume rm open-webui_db-config || echo "Volume open-webui_db-config does not exist, skipping."

# 2. Create necessary directories
echo "Creating storage directories..."
mkdir -p ./volumes/storage
mkdir -p /home/ilan/supabase_files/functions/main
touch /home/ilan/supabase_files/functions/main/index.ts

# Handle existing networks - remove and recreate if needed
echo "Setting up Docker networks..."
docker network ls | grep -q open-webui_supabase_network && docker network rm open-webui_supabase_network || echo "Network does not exist, will create new."
docker network ls | grep -q open-webui_open-webui && docker network rm open-webui_open-webui || echo "Network does not exist, will create new."

# Create networks with proper naming
docker network create open-webui_supabase_network || echo "Failed to create network, may already exist with different config."
docker network create open-webui_open-webui || echo "Failed to create network, may already exist with different config."

# 3. Start just the database container - critical service
echo "Starting Supabase database container..."
docker compose -f docker-compose-ilan-stack.yaml up -d supabase_db 2>&1 | tee -a "$LOGS_DIR/db_startup.log"

# Capture DB logs in background
docker logs supabase-db -f > "$LOGS_DIR/supabase-db.log" 2>&1 &
DB_LOG_PID=$!

# 4. Wait for the database to be ready - longer timeout
echo "Waiting for database to be ready (30 seconds)..."
sleep 30

# 5. Check if database is ready
echo "Checking database connection..."
MAX_RETRIES=5
RETRY_COUNT=0

while ! docker exec supabase-db pg_isready -U postgres -h localhost; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Database failed to start properly after $MAX_RETRIES attempts. Please check the logs:"
    docker logs --tail 50 supabase-db
    echo "Full logs saved to $LOGS_DIR/supabase-db.log"
    kill $DB_LOG_PID 2>/dev/null || true
    cleanup
    exit 1
  fi
  echo "Database is not ready yet. Waiting another 15 seconds (attempt $RETRY_COUNT/$MAX_RETRIES)..."
  sleep 15
done

echo "✅ Database is ready. Initializing roles and schemas..."
kill $DB_LOG_PID 2>/dev/null || true

# 6. Initialize the database with required roles and schemas
docker exec supabase-db psql -U postgres -c "CREATE ROLE supabase_admin WITH LOGIN SUPERUSER PASSWORD 'password';" 2>/dev/null || echo "Role supabase_admin may already exist"
docker exec supabase-db psql -U postgres -c "CREATE ROLE authenticator WITH LOGIN NOINHERIT PASSWORD 'password';" 2>/dev/null || echo "Role authenticator may already exist"
docker exec supabase-db psql -U postgres -c "CREATE ROLE anon WITH NOINHERIT PASSWORD 'password';" 2>/dev/null || echo "Role anon may already exist"
docker exec supabase-db psql -U postgres -c "CREATE ROLE service_role WITH NOINHERIT PASSWORD 'password';" 2>/dev/null || echo "Role service_role may already exist"
docker exec supabase-db psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO supabase_admin;" 2>/dev/null || echo "Failed to grant privileges"
docker exec supabase-db psql -U postgres -c "CREATE ROLE supabase_auth_admin WITH LOGIN PASSWORD 'password';" 2>/dev/null || echo "Role supabase_auth_admin may already exist"
docker exec supabase-db psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO supabase_auth_admin;" 2>/dev/null || echo "Failed to grant privileges"
docker exec supabase-db psql -U postgres -c "CREATE ROLE supabase_storage_admin WITH LOGIN PASSWORD 'password';" 2>/dev/null || echo "Role supabase_storage_admin may already exist"
docker exec supabase-db psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO supabase_storage_admin;" 2>/dev/null || echo "Failed to grant privileges"

# Create _supabase database and analytics schema
echo "Creating _supabase database and analytics schema..."
docker exec supabase-db psql -U postgres -c "CREATE DATABASE _supabase WITH OWNER = supabase_admin;" 2>/dev/null || echo "Database _supabase may already exist"
docker exec supabase-db psql -U postgres -d _supabase -c "CREATE SCHEMA IF NOT EXISTS _analytics;" 2>/dev/null || echo "Schema _analytics may already exist"
docker exec supabase-db psql -U postgres -d _supabase -c "ALTER SCHEMA _analytics OWNER TO supabase_admin;" 2>/dev/null || echo "Failed to alter schema owner"

# 7. Start services one by one, stopping on errors for critical services
echo "Starting Supabase core services..."

# Critical services - will stop script if they fail
check_service "supabase_meta" "supabase-meta" 15 3 true
check_service "supabase_pooler" "supabase-pooler" 15 3 true
check_service "supabase_kong" "supabase-kong" 15 3 true
check_service "supabase_rest" "supabase-rest" 15 3 true
check_service "supabase_auth" "supabase-auth" 15 3 true
check_service "supabase_analytics" "supabase-analytics" 15 3 true

# Non-critical services - will continue if they fail
check_service "supabase_storage" "supabase-storage" 15 3 false
check_service "supabase_imgproxy" "supabase-imgproxy" 10 2 false
check_service "supabase_realtime" "realtime-dev.supabase-realtime" 15 3 false
check_service "supabase_edge_functions" "supabase-edge-functions" 10 2 false
check_service "supabase_vector" "supabase-vector" 10 2 false
check_service "supabase_studio" "supabase-studio" 15 3 false

# 8. Check service status and scan for errors
echo "=================== Running Services ==================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep supabase
echo "======================================================="

echo "Scanning logs for common errors..."
for service in supabase-db supabase-meta supabase-pooler supabase-kong supabase-rest supabase-auth supabase-analytics supabase-storage supabase-imgproxy realtime-dev.supabase-realtime supabase-edge-functions supabase-vector supabase-studio; do
  scan_logs_for_errors $service
done

echo "===== SERVICE STATUS SUMMARY ====="
for service in supabase-db supabase-meta supabase-pooler supabase-kong supabase-rest supabase-auth supabase-analytics supabase-storage supabase-imgproxy realtime-dev.supabase-realtime supabase-edge-functions supabase-vector supabase-studio; do
  if docker ps | grep -q $service; then
    echo "✅ $service: Running"
  else
    echo "❌ $service: Not running or failed"
    echo "Check logs at $LOGS_DIR/${service}.log"
  fi
done

echo "✅ Supabase stack initialization complete!"
echo "📁 Service logs saved to $LOGS_DIR"
echo "🔗 Supabase Studio:   http://localhost:3003"
echo "🔗 API Gateway:       http://localhost:8084"
echo "🔗 REST API:          http://localhost:3012"
echo "🔗 Analytics:         http://localhost:4012"
echo ""
echo "To view logs for a specific service, run:"
echo "cat $LOGS_DIR/service-name.log"
echo ""
echo "To run diagnostics on logs, run:"
echo "./analyze_supabase_logs.sh" 