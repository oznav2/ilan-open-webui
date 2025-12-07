#!/usr/bin/env python3
"""
Docker Compose Version Comment Viewer
------------------------------------
This script displays the version comments added to the docker-compose file
in a nicely formatted table.
"""

import sys
import re
import yaml
from tabulate import tabulate

# Input file
DOCKER_COMPOSE_FILE = "docker-compose-ilan-stack-commented.yaml"

def extract_service_versions(file_path):
    """Extract service names, images and version comments from the docker-compose file"""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Parse with YAML to get service structure
        with open(file_path, 'r') as f:
            yaml_data = yaml.safe_load(f)
            
        services = []
        
        # Regex to find version comments before image lines
        version_comment_pattern = re.compile(r'^\s+# Version: (.+)$\n^\s+image: (.+)$', re.MULTILINE)
        
        # Find all version comments
        matches = version_comment_pattern.findall(content)
        
        # Create dictionary of image to version
        image_to_version = {img: ver for ver, img in matches}
        
        # Process each service in the docker-compose file
        for service_name, service_config in yaml_data.get('services', {}).items():
            if 'image' in service_config:
                image = service_config['image']
                version = image_to_version.get(image, "No version comment")
                
                # Extract container name and tag
                if ':' in image:
                    container, tag = image.rsplit(':', 1)
                else:
                    container = image
                    tag = "latest (implicit)"
                
                services.append([
                    service_name,
                    container,
                    tag,
                    version
                ])
                
        return services
    except Exception as e:
        print(f"Error processing file: {e}")
        sys.exit(1)

def main():
    """Main entry point"""
    print("Docker Compose Version Comments")
    print("-----------------------------")
    
    # Extract service versions
    services = extract_service_versions(DOCKER_COMPOSE_FILE)
    
    # Sort by service name
    services.sort(key=lambda x: x[0])
    
    # Display as table
    headers = ["Service", "Container", "Tag", "Latest Version"]
    print(tabulate(services, headers=headers, tablefmt="grid"))
    
    # Print summary
    version_count = sum(1 for service in services if service[3] != "No version comment")
    print(f"\nSummary: {version_count} of {len(services)} services have version comments.")

if __name__ == "__main__":
    main() 