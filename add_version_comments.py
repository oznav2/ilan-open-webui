#!/usr/bin/env python3
"""
Docker Compose Version Comment Adder
------------------------------------
This script adds version number comments to each service in a docker-compose file
based on the versions collected in the docker_versions.json file.
"""

import os
import sys
import json
import re
from datetime import datetime

# Input files
DOCKER_COMPOSE_FILE = "docker-compose-ilan-stack.yaml"
JSON_DATA_FILE = "docker_versions.json"
OUTPUT_FILE = "docker-compose-ilan-stack-commented.yaml"

def load_json_data(file_path):
    """Load version data from JSON file"""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading JSON data: {e}")
        sys.exit(1)

def load_file_lines(file_path):
    """Load file lines"""
    try:
        with open(file_path, 'r') as f:
            return f.readlines()
    except Exception as e:
        print(f"Error loading file: {e}")
        sys.exit(1)

def add_version_comments(lines, version_data):
    """Add version comments to services in docker-compose file"""
    # Dictionary to track changes
    changes = []
    
    # Get available versions
    container_versions = version_data.get("container_versions", {})
    
    # New lines to build the updated file
    new_lines = []
    
    # Pattern to match service definition
    service_pattern = re.compile(r'^(\s+)(\w+):')
    
    # Pattern to match image definition
    image_pattern = re.compile(r'^(\s+)image:\s+(.+)$')
    
    # Variables to track state
    current_service = None
    current_indent = None
    version_comment_added = False
    
    # Process each line
    for i, line in enumerate(lines):
        # Check if this is a service definition
        service_match = service_pattern.match(line)
        if service_match:
            current_indent = service_match.group(1)
            current_service = service_match.group(2)
            version_comment_added = False
            
        # Check if this is an image definition
        image_match = image_pattern.match(line)
        if image_match and current_service:
            indent = image_match.group(1)
            image = image_match.group(2)
            
            # Extract container name from image
            if ":" in image:
                container, tag = image.rsplit(":", 1)
            else:
                container = image
                
            # Check if we have a version for this container
            version = container_versions.get(container, "unknown")
            
            # Only add comment if a version was found
            if version not in ["unknown", "latest", None]:
                # Add version comment before image line
                version_comment = f"{indent}# Version: {version}\n"
                new_lines.append(version_comment)
                version_comment_added = True
                
                changes.append({
                    "service": current_service,
                    "image": image,
                    "version": version
                })
        
        # Add the original line
        new_lines.append(line)
    
    return new_lines, changes

def main():
    """Main entry point"""
    print(f"Docker Compose Version Comment Adder")
    print(f"----------------------------------")
    
    # Make backup of original file
    backup_file = f"{DOCKER_COMPOSE_FILE}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
    os.system(f"cp {DOCKER_COMPOSE_FILE} {backup_file}")
    print(f"Created backup at {backup_file}")
    
    # Load data
    version_data = load_json_data(JSON_DATA_FILE)
    original_lines = load_file_lines(DOCKER_COMPOSE_FILE)
    
    # Add version comments
    updated_lines, changes = add_version_comments(original_lines, version_data)
    
    # Write updated file
    with open(OUTPUT_FILE, 'w') as f:
        f.writelines(updated_lines)
    
    # Print summary
    print(f"\nAdded version comments to {len(changes)} services:")
    for change in changes:
        print(f"  - {change['service']}: {change['image']} (Version: {change['version']})")
    
    print(f"\nUpdated file saved to {OUTPUT_FILE}")
    print(f"Review the changes before replacing the original file.")

if __name__ == "__main__":
    main() 