#!/bin/bash

# Sync Ollama Models Script
# This script copies all models from the host to the Ollama container

echo "Starting Ollama model sync..."

# Check if Ollama container is running
if ! docker ps | grep -q "ollama"; then
    echo "Error: Ollama container is not running. Please start it first."
    exit 1
fi

# Create necessary directories in container
echo "Creating directories in container..."
docker exec ollama mkdir -p /root/.ollama/models/manifests/registry.ollama.ai
docker exec ollama mkdir -p /root/.ollama/models/blobs

# Copy manifests
echo "Copying model manifests..."
docker cp /home/ilan/ollama-models/models/manifests/registry.ollama.ai/. ollama:/root/.ollama/models/manifests/registry.ollama.ai/

# Copy blobs (this may take a while for large models)
echo "Copying model blobs (this may take several minutes)..."
docker cp /home/ilan/ollama-models/models/blobs/. ollama:/root/.ollama/models/blobs/

# Wait a moment for Ollama to recognize the models
echo "Waiting for Ollama to recognize models..."
sleep 5

# List available models
echo "Available models:"
docker exec ollama ollama list

echo "Model sync complete!" 