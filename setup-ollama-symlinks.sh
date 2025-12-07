#!/bin/bash

# Setup Ollama Symlinks Script
# This creates a lightweight ollama directory structure with symlinks to your models

echo "Setting up Ollama symlinks to avoid Docker overlay issues..."

# Create a lightweight ollama directory
sudo rm -rf /home/ilan/ollama-lightweight 2>/dev/null
mkdir -p /home/ilan/ollama-lightweight/models

# Copy the SSH keys (small files)
cp /home/ilan/ollama-models/id_ed25519* /home/ilan/ollama-lightweight/

# Create symlinks to the actual model data
ln -sf /home/ilan/ollama-models/models/blobs /home/ilan/ollama-lightweight/models/blobs
ln -sf /home/ilan/ollama-models/models/manifests /home/ilan/ollama-lightweight/models/manifests

# Set proper permissions
sudo chown -R 1000:1000 /home/ilan/ollama-lightweight

echo "Lightweight ollama directory created at /home/ilan/ollama-lightweight"
echo "This directory contains symlinks to your actual models to avoid space issues."
echo ""
echo "To use this, update your docker-compose.yaml volume mount to:"
echo "  - /home/ilan/ollama-lightweight:/root/.ollama" 