import requests
import json
import re
import yaml
from datetime import datetime
from packaging import version

# Path to the docker-compose file
DOCKER_COMPOSE_FILE = "docker-compose-ilan-stack.yaml"

# Select containers that are likely to succeed
CONTAINERS_TO_CHECK = [
    "qdrant/qdrant",
    "ollama/ollama",
    "prom/prometheus",
    "n8nio/n8n",
    "flowiseai/flowise"
]

def get_latest_version(repo_name):
    """Get the latest version for a Docker Hub repository"""
    print(f"Checking {repo_name}...")
    url = f"https://hub.docker.com/v2/repositories/{repo_name}/tags/?page_size=10"
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        # Look for semantic version tags (v1.2.3 or 1.2.3)
        for tag in data.get('results', []):
            name = tag['name']
            if (name.startswith('v') and '.' in name) or (name[0].isdigit() and '.' in name):
                return name
                
        # If no semantic version found, return latest tag
        if data.get('results'):
            return data['results'][0]['name']
        return "unknown"
        
    except Exception as e:
        print(f"Error checking {repo_name}: {e}")
        return "error"

def parse_version_str(version_str):
    """Parse a version string into a comparable version object"""
    # Remove 'v' prefix if present
    if version_str and version_str.startswith('v'):
        version_str = version_str[1:]
    
    # Try to convert to a version object
    try:
        return version.parse(version_str)
    except:
        return None

def extract_container_versions(yaml_file):
    """Extract container versions from the docker-compose file"""
    try:
        with open(yaml_file, 'r') as f:
            compose_data = yaml.safe_load(f)
        
        # Dictionary to store container:version from docker-compose
        container_versions = {}
        
        for service_name, service_config in compose_data.get('services', {}).items():
            if 'image' in service_config:
                image = service_config['image']
                
                # Extract the container name and version
                # Format: registry/image:tag or image:tag
                if ':' in image:
                    container, tag = image.rsplit(':', 1)
                    container_versions[container] = tag
                else:
                    container_versions[image] = 'latest'
        
        return container_versions
    
    except Exception as e:
        print(f"Error parsing docker-compose file: {e}")
        return {}

def compare_versions(compose_versions, latest_versions):
    """Compare versions from docker-compose with latest available versions"""
    results = []
    
    for container, latest_version in latest_versions.items():
        # Check if this container exists in the compose file
        if container in compose_versions:
            compose_version = compose_versions[container]
            
            # Special case for 'latest' tag
            if compose_version == 'latest':
                results.append({
                    "container": container,
                    "compose_version": compose_version,
                    "latest_version": latest_version,
                    "status": "UNKNOWN (using latest tag)"
                })
                continue
            
            # Parse versions for comparison
            v_compose = parse_version_str(compose_version)
            v_latest = parse_version_str(latest_version)
            
            if v_compose and v_latest and v_compose < v_latest:
                results.append({
                    "container": container,
                    "compose_version": compose_version,
                    "latest_version": latest_version,
                    "status": "UPDATE AVAILABLE"
                })
            else:
                results.append({
                    "container": container,
                    "compose_version": compose_version,
                    "latest_version": latest_version,
                    "status": "UP TO DATE"
                })
        else:
            # Container not found in compose file
            results.append({
                "container": container,
                "compose_version": "NOT FOUND",
                "latest_version": latest_version,
                "status": "NOT IN COMPOSE FILE"
            })
    
    return results

def main():
    print("Checking Docker container versions...")
    latest_versions = {}
    
    # Get latest versions from Docker Hub
    for container in CONTAINERS_TO_CHECK:
        version = get_latest_version(container)
        latest_versions[container] = version
        print(f"{container}: {version}")
    
    # Get versions from docker-compose
    print("\nExtracting versions from docker-compose file...")
    compose_versions = extract_container_versions(DOCKER_COMPOSE_FILE)
    
    # Compare versions
    print("\nComparing versions...")
    comparison_results = compare_versions(compose_versions, latest_versions)
    
    # Display results
    print("\n--- Version Comparison Results ---")
    for result in comparison_results:
        print(f"{result['container']}:")
        print(f"  Compose version: {result['compose_version']}")
        print(f"  Latest version: {result['latest_version']}")
        print(f"  Status: {result['status']}")
        print()
    
    # Save results to JSON
    output_data = {
        "scan_date": datetime.now().isoformat(),
        "container_versions": latest_versions,
        "compose_versions": compose_versions,
        "comparison_results": comparison_results
    }
    
    with open("container_versions.json", "w") as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Results saved to container_versions.json")

if __name__ == "__main__":
    main() 