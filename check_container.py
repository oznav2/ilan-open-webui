import requests

print("Checking the latest version of qdrant/qdrant container...")
url = "https://hub.docker.com/v2/repositories/qdrant/qdrant/tags/?page_size=10"

try:
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()
    
    for tag in data.get('results', []):
        if tag['name'].startswith('v') and '.' in tag['name']:
            print(f"Latest version found: {tag['name']}")
            break
    else:
        print("No version tag found")
        
except requests.exceptions.RequestException as e:
    print(f"Error: {e}") 