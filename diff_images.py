#!/usr/bin/env python3
"""
Docker Compose Image Diff
------------------------
This script displays a side-by-side comparison of Docker images 
before and after version updates.
"""

import sys
import yaml
import re
from tabulate import tabulate

# Input files
ORIGINAL_FILE = "docker-compose-ilan-stack.yaml"
UPDATED_FILE = "docker-compose-ilan-stack-versioned.yaml"

def extract_images(file_path):
    """Extract all image definitions from a docker-compose file"""
    try:
        with open(file_path, 'r') as f:
            data = yaml.safe_load(f)
        
        images = {}
        services = data.get("services", {})
        for service_name, service_config in services.items():
            if "image" in service_config:
                images[service_name] = service_config["image"]
        
        return images
    except Exception as e:
        print(f"Error loading file {file_path}: {e}")
        sys.exit(1)

def compare_images(original_images, updated_images):
    """Compare original and updated images"""
    comparison = []
    
    # Find all unique service names
    all_services = set(original_images.keys()) | set(updated_images.keys())
    
    for service in sorted(all_services):
        original = original_images.get(service, "N/A")
        updated = updated_images.get(service, "N/A")
        
        # Determine if this service was updated
        status = "CHANGED" if original != updated else "UNCHANGED"
        
        comparison.append([service, original, updated, status])
    
    return comparison

def main():
    """Main entry point"""
    print("Docker Compose Image Comparison")
    print("------------------------------")
    
    # Extract images from both files
    original_images = extract_images(ORIGINAL_FILE)
    updated_images = extract_images(UPDATED_FILE)
    
    # Compare images
    comparison = compare_images(original_images, updated_images)
    
    # Display comparison
    print("\nImage version comparison:")
    headers = ["Service", "Original Image", "Updated Image", "Status"]
    print(tabulate(comparison, headers=headers, tablefmt="grid"))
    
    # Print summary
    changed_count = sum(1 for row in comparison if row[3] == "CHANGED")
    print(f"\nSummary: {changed_count} services were updated with specific versions.")

if __name__ == "__main__":
    main() 