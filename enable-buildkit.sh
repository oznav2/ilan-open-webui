#!/bin/bash

# Enable Docker BuildKit for better caching and parallel builds
# This script sets the necessary environment variables for BuildKit

echo "Enabling Docker BuildKit..."

# Export BuildKit environment variables
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain
export COMPOSE_DOCKER_CLI_BUILD=1

echo "Docker BuildKit enabled successfully!"
echo "Environment variables set:"
echo "  DOCKER_BUILDKIT=1"
echo "  BUILDKIT_PROGRESS=plain"
echo "  COMPOSE_DOCKER_CLI_BUILD=1"
echo ""
echo "You can now run docker-compose build with BuildKit optimizations."
echo "Example: docker-compose -f docker-compose-ilan-stack.yaml build pipelines"