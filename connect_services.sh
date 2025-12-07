#!/bin/bash
set -e

echo "============================================"
echo "   Connecting Supabase Services to Networks"
echo "============================================"

# Create networks if they don't exist
docker network inspect open-webui_supabase_network >/dev/null 2>&1 || docker network create open-webui_supabase_network
docker network inspect open-webui_open-webui >/dev/null 2>&1 || docker network create open-webui_open-webui

# Connect services to supabase_network
for service in supabase-db supabase-auth supabase-rest supabase-pooler supabase-storage supabase-meta supabase-analytics supabase-vector supabase-kong realtime-dev.supabase-realtime supabase-edge-functions supabase-imgproxy supabase-studio; do
  echo "Connecting $service to open-webui_supabase_network..."
  docker network connect open-webui_supabase_network $service 2>/dev/null || echo "$service already connected or doesn't exist"
done

# Connect services to open-webui
for service in supabase-db supabase-auth supabase-rest supabase-pooler supabase-storage supabase-meta supabase-analytics supabase-vector supabase-kong realtime-dev.supabase-realtime supabase-edge-functions supabase-imgproxy supabase-studio; do
  echo "Connecting $service to open-webui_open-webui..."
  docker network connect open-webui_open-webui $service 2>/dev/null || echo "$service already connected or doesn't exist"
done

echo "Verifying network connections:"
for service in supabase-db supabase-auth supabase-rest supabase-pooler supabase-storage supabase-meta supabase-analytics supabase-vector supabase-kong realtime-dev.supabase-realtime supabase-edge-functions supabase-imgproxy supabase-studio; do
  if docker ps -q -f name=$service >/dev/null 2>&1; then
    echo "Networks for $service: $(docker inspect -f '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' $service)"
  else
    echo "$service is not running"
  fi
done

echo "============================================"
echo "   Connection Process Complete"
echo "============================================" 