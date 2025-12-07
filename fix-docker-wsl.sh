#!/bin/bash
# Docker WSL2 Quick Fix Script
# Resolves Docker Desktop connectivity issues in WSL2

echo "🐳 Docker WSL2 Quick Fix Script"
echo "==============================="

# Function to check if Docker Desktop is running
check_docker_desktop() {
    if [ ! -S /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock ]; then
        echo "❌ Docker Desktop socket not found!"
        echo "   Please ensure Docker Desktop is running on Windows"
        echo "   Expected socket: /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock"
        return 1
    fi
    echo "✅ Docker Desktop socket found"
    return 0
}

# Function to fix Docker socket
fix_docker_socket() {
    echo "🔧 Fixing Docker socket..."
    
    # Remove existing socket if present
    if [ -L /var/run/docker.sock ] || [ -S /var/run/docker.sock ]; then
        echo "   Removing existing socket..."
        sudo rm -f /var/run/docker.sock
    fi
    
    # Create correct symbolic link
    echo "   Creating symbolic link to Docker Desktop..."
    sudo ln -s /mnt/wsl/docker-desktop/shared-sockets/guest-services/docker.proxy.sock /var/run/docker.sock
    
    # Set permissions
    echo "   Setting permissions..."
    sudo chmod 666 /var/run/docker.sock
    
    echo "✅ Docker socket fixed"
}

# Function to test Docker connection
test_docker() {
    echo "🧪 Testing Docker connection..."
    
    if docker version > /dev/null 2>&1; then
        echo "✅ Docker is working!"
        echo "   Server version: $(docker info --format "{{.ServerVersion}}" 2>/dev/null)"
        echo "   Current context: $(docker context show)"
        
        # Test Docker Compose
        if docker-compose --version > /dev/null 2>&1; then
            echo "✅ Docker Compose is working!"
            echo "   Version: $(docker-compose --version)"
        else
            echo "⚠️  Docker Compose test failed"
        fi
        
        return 0
    else
        echo "❌ Docker test failed"
        return 1
    fi
}

# Function to show Docker context info
show_context_info() {
    echo "📋 Docker Context Information:"
    echo "   Current context: $(docker context show 2>/dev/null || echo 'Unknown')"
    echo "   Available contexts:"
    docker context ls 2>/dev/null | head -5
}

# Main execution
main() {
    echo
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        echo "⚠️  Please run this script as a regular user (not root)"
        echo "   The script will use sudo when needed"
        exit 1
    fi
    
    # Check Docker Desktop availability
    if ! check_docker_desktop; then
        echo
        echo "🛠️  Manual Steps:"
        echo "   1. Start Docker Desktop on Windows"
        echo "   2. Wait for it to fully load"
        echo "   3. Run this script again"
        exit 1
    fi
    
    echo
    
    # Fix Docker socket
    fix_docker_socket
    
    echo
    
    # Test Docker connection
    if test_docker; then
        echo
        echo "🎉 Docker setup completed successfully!"
        echo
        show_context_info
        echo
        echo "💡 Tip: If you restart WSL, you may need to run this script again"
        echo "    or update your /etc/wsl.conf with the correct socket path"
    else
        echo
        echo "❌ Docker setup failed. Please check the troubleshooting guide."
        echo
        echo "🔍 Debug information:"
        echo "   Socket link: $(ls -la /var/run/docker.sock 2>/dev/null || echo 'Not found')"
        echo "   Socket permissions: $(stat -c '%A' /var/run/docker.sock 2>/dev/null || echo 'N/A')"
        echo "   User groups: $(groups)"
        echo
        echo "📖 See docker-troubleshooting-guide.md for detailed troubleshooting"
    fi
}

# Run main function
main "$@" 