import requests
import re
import json
from packaging import version
from datetime import datetime

# --- Configuration ---
IMAGES_TO_CHECK = [
    "qdrant/qdrant",
    "ollama/ollama:latest",
    "ghcr.io/berriai/litellm:main-latest", # GHCR - might fail without auth
    "apache/tika:latest-full", # Check for numeric tags
    "ghcr.io/open-webui/pipelines:latest-cuda", # GHCR - might fail
    "prom/prometheus",
    "n8nio/n8n:latest",
    "quay.io/unstructured-io/unstructured-api:latest",
    "ghcr.io/linkwarden/linkwarden:latest", # GHCR - might fail
    "flowiseai/flowise",
    "searxng/searxng:latest",
    "nicolargo/glances:latest",
    "linuxserver/duplicati:latest",
    "dpage/pgadmin4:latest"
]

# Output JSON file
OUTPUT_FILE = "docker_versions.json"

# --- Version Parsing ---
def is_semantic_version(tag):
    """Check if a tag looks like a semantic version (vX.Y.Z or X.Y.Z)."""
    return re.match(r'^v?(\d+)\.(\d+)\.(\d+)([-+].*)?$', tag)

def parse_version(tag):
    """Parse a semantic version tag, removing 'v' prefix."""
    match = re.match(r'^v?(\d+\.\d+\.\d+.*)', tag)
    if match:
        try:
            return version.parse(match.group(1))
        except version.InvalidVersion:
            return None
    return None

# --- Registry API Functions ---
def get_dockerhub_tags(repo_name):
    """Fetch tags for a Docker Hub repository."""
    tags = []
    url = f"https://hub.docker.com/v2/repositories/{repo_name}/tags/?page_size=100"
    try:
        while url:
            response = requests.get(url, timeout=15)
            response.raise_for_status()
            data = response.json()
            tags.extend([tag['name'] for tag in data.get('results', [])])
            url = data.get('next')
        return tags
    except requests.exceptions.RequestException as e:
        print(f"Error fetching Docker Hub tags for {repo_name}: {e}")
        return None

def get_quayio_tags(repo_name):
    """Fetch tags for a Quay.io repository."""
    tags = []
    url = f"https://quay.io/api/v1/repository/{repo_name}/tag/"
    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        data = response.json()
        tags = [tag['name'] for tag in data.get('tags', []) if not tag.get('is_manifest_list', False)] # Basic check
        # Quay API might need pagination for many tags, simplified here
        return tags
    except requests.exceptions.RequestException as e:
        print(f"Error fetching Quay.io tags for {repo_name}: {e}")
        return None

def get_ghcr_tags(repo_name):
    """Attempt to fetch tags for a GHCR repository (might require auth)."""
    # GHCR tag listing API often requires auth, this is a best effort for public repos
    print(f"Attempting to fetch tags for GHCR image: {repo_name}. This might fail without authentication.")
    # Use a common (but not official/stable) endpoint sometimes used by tools
    # This is less reliable than Docker Hub/Quay
    # Example repo_name: linkwarden/linkwarden
    url = f"https://ghcr.io/v2/{repo_name}/tags/list"
    headers = {"Accept": "application/vnd.docker.distribution.manifest.v2+json"}
    try:
        # Try without auth first
        response = requests.get(url, headers=headers, timeout=15)
        if response.status_code == 401:
             print(f"Authentication required for {repo_name} on GHCR. Cannot fetch tags.")
             return None
        response.raise_for_status()
        data = response.json()
        return data.get('tags', [])
    except requests.exceptions.RequestException as e:
        print(f"Error fetching GHCR tags for {repo_name}: {e}")
        return None
    except Exception as e:
        print(f"Unexpected error fetching GHCR tags for {repo_name}: {e}")
        return None


# --- Main Logic ---
def find_latest_version(tags):
    """Find the highest semantic version from a list of tags."""
    if not tags:
        return None
    
    semantic_versions = {}
    for tag in tags:
        if is_semantic_version(tag):
            parsed = parse_version(tag)
            if parsed:
                semantic_versions[parsed] = tag # Store original tag name

    if not semantic_versions:
        # Fallback: Look for purely numeric tags like '2.36' if no semver found
        numeric_versions = {}
        for tag in tags:
             if re.match(r'^(\d+)\.(\d+)$', tag) or re.match(r'^(\d+)$', tag):
                 try:
                    parsed_num = version.parse(tag)
                    numeric_versions[parsed_num] = tag
                 except version.InvalidVersion:
                     continue
        if numeric_versions:
            latest_parsed = max(numeric_versions.keys())
            return numeric_versions[latest_parsed]
        return None # No suitable version found

    latest_parsed = max(semantic_versions.keys())
    return semantic_versions[latest_parsed]


def main():
    print("--- Fetching Latest Image Versions ---")
    results = {}
    failed_images = []

    for image_ref in IMAGES_TO_CHECK:
        print(f"\nProcessing: {image_ref}")
        # Split image name and potential existing tag
        if ':' in image_ref:
            image_name, _ = image_ref.split(':', 1)
        else:
            image_name = image_ref

        tags = None
        # Determine registry and repo name
        if '/' not in image_name: # Docker Hub official image
            repo_name = f"library/{image_name}"
            tags = get_dockerhub_tags(repo_name)
        elif image_name.startswith("ghcr.io/"):
            repo_name = image_name.split('/', 1)[1]
            tags = get_ghcr_tags(repo_name)
        elif image_name.startswith("quay.io/"):
            repo_name = image_name.split('/', 1)[1]
            tags = get_quayio_tags(repo_name)
        elif image_name.startswith("mcr.microsoft.com/"):
            # MCR often doesn't have a simple tag listing API, skip for now
            print("Skipping MCR image (tag listing not easily available).")
            failed_images.append(image_ref)
            continue
        elif '.' not in image_name.split('/')[0]: # Likely Docker Hub user/org repo
            repo_name = image_name
            tags = get_dockerhub_tags(repo_name)
        else: # Assuming other registry (like a private one, or complex case)
            print(f"Cannot determine registry or standard API for: {image_name}. Skipping.")
            failed_images.append(image_ref)
            continue

        if tags is not None:
            latest_version = find_latest_version(tags)
            if latest_version:
                print(f"Found latest version for {image_name}: {latest_version}")
                results[image_ref] = latest_version
            else:
                print(f"Could not determine a suitable latest version for {image_name} from tags.")
                failed_images.append(image_ref)
        else:
             failed_images.append(image_ref)

    # Create output dictionary with metadata
    output_data = {
        "scan_date": datetime.now().isoformat(),
        "successful_images": results,
        "failed_images": failed_images
    }
    
    # Save to JSON file
    try:
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(output_data, f, indent=2)
        print(f"\nResults saved to {OUTPUT_FILE}")
    except Exception as e:
        print(f"\nError saving results to file: {e}")

    print("\n--- Summary ---")
    print("Successfully found versions for:")
    for img, ver in results.items():
        print(f"- {img}: {ver}")

    if failed_images:
        print("\nCould not automatically determine versions for:")
        for img in failed_images:
            print(f"- {img}")
    print("----------------")

if __name__ == "__main__":
    main()