#!/bin/bash

# Migrate Ollama Models to Docker Volume
# This copies models from host directory to a Docker named volume

echo "Starting migration to Docker named volume..."

# First, create the volume and start Ollama
echo "Creating Ollama container with named volume..."
docker-compose -f docker-compose-ilan-stack.yaml up -d ollama

# Wait for container to be ready
echo "Waiting for container to be ready..."
sleep 10

# Copy models to the volume using a temporary container
echo "Copying SSH keys..."
docker cp /home/ilan/ollama-models/id_ed25519 ollama:/root/.ollama/
docker cp /home/ilan/ollama-models/id_ed25519.pub ollama:/root/.ollama/

echo "Creating models directory structure..."
docker exec ollama mkdir -p /root/.ollama/models/blobs
docker exec ollama mkdir -p /root/.ollama/models/manifests

echo "Copying model manifests (this will take a moment)..."
docker cp /home/ilan/ollama-models/models/manifests/. ollama:/root/.ollama/models/manifests/

echo "Copying model blobs (this will take several minutes - 26GB of data)..."
docker cp /home/ilan/ollama-models/models/blobs/. ollama:/root/.ollama/models/blobs/

# Restart Ollama to recognize all models
echo "Restarting Ollama to recognize models..."
docker-compose -f docker-compose-ilan-stack.yaml restart ollama

# Wait and check
echo "Waiting for Ollama to start..."
sleep 15

echo "Final result:"
docker exec ollama ollama list

echo "Migration complete!" 