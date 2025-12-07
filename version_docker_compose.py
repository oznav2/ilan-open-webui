#!/usr/bin/env python3
"""
Docker Compose Version Updater (Combined)
----------------------------------------
This script adds version comments to each service in a docker-compose file
AND optionally updates 'latest' tags to specific version numbers.
"""

import os
import sys
import yaml
import json
import re
import argparse
import shutil
from datetime import datetime
from tabulate import tabulate

def load_json_data(file_path):
    """Load version data from JSON file"""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading JSON data: {e}")
        sys.exit(1)

def load_file_content(file_path):
    """Load file content as string"""
    try:
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        print(f"Error loading file: {e}")
        sys.exit(1)

def load_yaml_data(file_path):
    """Load YAML data"""
    try:
        with open(file_path, 'r') as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"Error parsing YAML: {e}")
        sys.exit(1)

def add_version_comments_and_update_tags(content, yaml_data, version_data, update_tags=False, skip_existing=True):
    """Add version comments and optionally update tags to specific versions"""
    # Get available versions
    container_versions = version_data.get("container_versions", {})
    
    # Track changes
    changes = []
    
    # Process content line by line
    lines = content.splitlines()
    new_lines = []
    
    # Variables to track state
    current_service = None
    version_comments_added = set()  # To avoid adding the same comment multiple times
    
    # Pattern to match service definition
    service_pattern = re.compile(r'^(\s+)(\w+):')
    
    # Pattern to match image definition
    image_pattern = re.compile(r'^(\s+image:\s+)(.+)$')
    
    # Pattern to match existing version comments
    version_comment_pattern = re.compile(r'^\s+# Version:')
    
    for line in lines:
        # Check if this is a service definition
        service_match = service_pattern.match(line)
        if service_match:
            current_service = service_match.group(2)
        
        # Check if this is an existing version comment (to skip it if updating)
        if version_comment_pattern.match(line) and skip_existing:
            # Skip this line if we're updating an existing file that already has comments
            continue
            
        # Check if this is an image definition
        image_match = image_pattern.match(line)
        if image_match and current_service:
            indent_plus_image = image_match.group(1)
            image = image_match.group(2)
            
            # Extract container name and tag
            if ":" in image:
                container, tag = image.rsplit(":", 1)
            else:
                container = image
                tag = "latest"  # Implicit latest tag
            
            # Check if we have a version for this container
            if container in container_versions and container_versions[container] not in ["unknown", "UNKNOWN", None]:
                version = container_versions[container]
                indent = ' ' * (len(indent_plus_image) - len('image: '))
                
                # Add version comment
                version_comment = f"{indent}# Version: {version}"
                new_lines.append(version_comment)
                
                # Update tag if requested and it's a "latest" tag
                if update_tags and (tag == "latest" or container == image):
                    if container == image:  # No tag specified
                        new_image = f"{container}:{version}"
                        new_line = f"{indent_plus_image}{new_image}"
                    else:  # Has "latest" tag
                        new_image = f"{container}:{version}"
                        new_line = f"{indent_plus_image}{new_image}"
                    
                    changes.append({
                        "service": current_service,
                        "old_image": image,
                        "new_image": new_image,
                        "version": version,
                        "change_type": "tag_updated"
                    })
                else:
                    # Keep the original image line
                    new_line = line
                    changes.append({
                        "service": current_service,
                        "image": image,
                        "version": version,
                        "change_type": "comment_added"
                    })
            else:
                # No version info available, keep the line as is
                new_line = line
        else:
            # Keep non-image line as is
            new_line = line
        
        new_lines.append(new_line)
    
    # Join lines back into content
    new_content = '\n'.join(new_lines)
    
    return new_content, changes

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Docker Compose Version Updater (Combined)")
    parser.add_argument("--compose", dest="compose_file", default="docker-compose-ilan-stack.yaml",
                        help="Path to docker-compose file")
    parser.add_argument("--json", dest="json_file", default="docker_versions.json",
                        help="Path to version JSON file")
    parser.add_argument("--output", dest="output_file", default="docker-compose-ilan-stack-versioned.yaml",
                        help="Path to output file")
    parser.add_argument("--update-tags", dest="update_tags", action="store_true", 
                        help="Update 'latest' tags to specific versions")
    parser.add_argument("--no-skip-existing", dest="skip_existing", action="store_false",
                        help="Don't skip existing version comments")
    
    args = parser.parse_args()
    
    print("Docker Compose Version Updater (Combined)")
    print("---------------------------------------")
    
    # Make backup of original file
    backup_file = f"{args.compose_file}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
    shutil.copy2(args.compose_file, backup_file)
    print(f"Created backup at {backup_file}")
    
    # Load data
    version_data = load_json_data(args.json_file)
    content = load_file_content(args.compose_file)
    yaml_data = load_yaml_data(args.compose_file)
    
    # Add version comments and update tags
    new_content, changes = add_version_comments_and_update_tags(
        content, yaml_data, version_data, 
        update_tags=args.update_tags,
        skip_existing=args.skip_existing
    )
    
    # Write updated file
    with open(args.output_file, 'w') as f:
        f.write(new_content)
    
    # Count changes by type
    comments_added = sum(1 for change in changes if change["change_type"] == "comment_added")
    tags_updated = sum(1 for change in changes if change["change_type"] == "tag_updated")
    
    # Print summary
    print(f"\nSummary of changes:")
    print(f"  - Version comments added: {comments_added}")
    
    if args.update_tags:
        print(f"  - Image tags updated: {tags_updated}")
        
        # Print details of tag updates
        if tags_updated > 0:
            print("\nImage tag updates:")
            tag_updates = [
                [change["service"], change["old_image"], change["new_image"]]
                for change in changes if change["change_type"] == "tag_updated"
            ]
            print(tabulate(
                tag_updates, 
                headers=["Service", "Old Image", "New Image"],
                tablefmt="grid"
            ))
    
    print(f"\nUpdated file saved to {args.output_file}")
    print("Review the changes before replacing the original file.")

if __name__ == "__main__":
    main() 