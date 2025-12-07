#!/bin/bash

# Flag file to track if packages have been installed
INSTALL_FLAG="/app/.packages_installed"

# Install additional requirements if they exist and haven't been installed yet
if [ -f /app/requirements.txt ] && [ ! -f "$INSTALL_FLAG" ]; then
    echo "Installing additional requirements..."
    pip install --no-cache-dir --disable-pip-version-check --quiet -r /app/requirements.txt
    if [ $? -eq 0 ]; then
        echo "Requirements installed successfully."
        touch "$INSTALL_FLAG"
    else
        echo "Failed to install requirements. Exiting."
        exit 1
    fi
elif [ -f "$INSTALL_FLAG" ]; then
    echo "Requirements already installed, skipping installation."
fi

# Start the main application
exec python main.py