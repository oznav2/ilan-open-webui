#!/bin/bash
set -e

echo "============================================"
echo "   Supabase DB Connectivity Check"
echo "============================================"

echo "Checking Supabase DB status:"
docker ps -a --filter "name=supabase-db" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo "Getting Supabase DB IP address:"
DB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' supabase-db)
echo "Supabase DB IP: $DB_IP"

echo "Networks that Supabase DB is connected to:"
docker inspect -f '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' supabase-db

echo "Checking if Supabase DB is accepting connections:"
docker exec supabase-db pg_isready -U postgres -h localhost

echo "Checking connectivity from Auth service:"
docker exec supabase-auth wget -q --spider --timeout=5 http://supabase_db:5432 || echo "Connection to DB failed from Auth service"

echo "Checking DNS resolution in Auth service:"
docker exec supabase-auth getent hosts supabase_db || echo "DNS resolution failed in Auth service"

echo "Testing connection to DB from Auth service:"
docker exec supabase-auth sh -c "nc -zv supabase_db 5432" || echo "Network connection test failed"

echo "Checking Docker networks:"
docker network ls

echo "============================================"
echo "   Connection Test Complete"
echo "============================================" 