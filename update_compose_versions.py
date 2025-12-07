#!/usr/bin/env python3
"""
Docker Compose Version Updater
------------------------------
This script updates image tags in a docker-compose file with specific version numbers
based on the output from docker_version_checker.py.
"""

import os
import sys
import yaml
import json
import re
import shutil
from datetime import datetime

# Input files
DOCKER_COMPOSE_FILE = "docker-compose-ilan-stack.yaml"
JSON_DATA_FILE = "docker_versions.json"
OUTPUT_FILE = "docker-compose-ilan-stack-versioned.yaml"

def load_json_data(file_path):
    """Load version data from JSON file"""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading JSON data: {e}")
        sys.exit(1)

def load_yaml_file(file_path):
    """Load docker-compose YAML file"""
    try:
        # Read the file without parsing to preserve comments and formatting
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Also parse with yaml to work with the structure
        with open(file_path, 'r') as f:
            data = yaml.safe_load(f)
        
        return content, data
    except Exception as e:
        print(f"Error loading YAML file: {e}")
        sys.exit(1)

def update_versions(yaml_content, yaml_data, version_data):
    """Update image tags with specific versions"""
    # Dictionary to track changes
    changes = []
    
    # Get available versions
    container_versions = version_data.get("container_versions", {})
    
    # Process each service in the docker-compose file
    services = yaml_data.get("services", {})
    for service_name, service_config in services.items():
        if "image" in service_config:
            image = service_config["image"]
            
            # Check if image has a tag
            if ":" in image:
                container, tag = image.rsplit(":", 1)
                
                # Check if we have a specific version for this container
                if container in container_versions and container_versions[container] not in ["latest", "UNKNOWN", None]:
                    new_version = container_versions[container]
                    
                    # Skip if it's not helpful to change (e.g., alpine -> specific version)
                    if tag in ["alpine", "latest-full", "latest-cuda"] and not tag.startswith("v"):
                        continue
                    
                    # Skip if the compose version is already specific enough
                    if any(char.isdigit() for char in tag) and tag not in ["latest"]:
                        continue
                    
                    # Create the replacement image name with specific version
                    new_image = f"{container}:{new_version}"
                    
                    # Replace in the YAML content (case sensitive, whole words only)
                    yaml_content = re.sub(
                        f"(\\s+image:\\s+){re.escape(image)}(\\s|$)", 
                        f"\\1{new_image}\\2", 
                        yaml_content
                    )
                    
                    changes.append({
                        "service": service_name,
                        "old_image": image,
                        "new_image": new_image
                    })
            else:
                # Handle images without a tag (implicitly latest)
                container = image
                # Check if we have a specific version for this container
                if container in container_versions and container_versions[container] not in ["latest", "UNKNOWN", None]:
                    new_version = container_versions[container]
                    new_image = f"{container}:{new_version}"
                    
                    # Replace in the YAML content (case sensitive, whole words only)
                    yaml_content = re.sub(
                        f"(\\s+image:\\s+){re.escape(container)}(\\s|$)", 
                        f"\\1{new_image}\\2", 
                        yaml_content
                    )
                    
                    changes.append({
                        "service": service_name,
                        "old_image": container,
                        "new_image": new_image
                    })
    
    return yaml_content, changes

def main():
    """Main entry point"""
    print(f"Docker Compose Version Updater")
    print(f"--------------------------")
    
    # Make backup of original file
    backup_file = f"{DOCKER_COMPOSE_FILE}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
    shutil.copy2(DOCKER_COMPOSE_FILE, backup_file)
    print(f"Created backup at {backup_file}")
    
    # Load data files
    version_data = load_json_data(JSON_DATA_FILE)
    yaml_content, yaml_data = load_yaml_file(DOCKER_COMPOSE_FILE)
    
    # Update versions
    updated_content, changes = update_versions(yaml_content, yaml_data, version_data)
    
    # Write updated file
    with open(OUTPUT_FILE, 'w') as f:
        f.write(updated_content)
    
    # Print summary
    print(f"\nUpdated {len(changes)} services with specific versions:")
    for change in changes:
        print(f"  - {change['service']}: {change['old_image']} → {change['new_image']}")
    
    print(f"\nUpdated file saved to {OUTPUT_FILE}")
    print(f"Review the changes before replacing the original file.")

if __name__ == "__main__":
    main() 