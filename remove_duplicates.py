#!/usr/bin/env python3
import json
import sys
import re
from collections import OrderedDict

def remove_duplicate_keys(file_path):
    """Remove duplicate keys from JSON file, keeping the first occurrence of each key"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Parse JSON while tracking duplicates
    seen_keys = set()
    duplicates = []
    
    # Split into lines for processing
    lines = content.split('\n')
    clean_lines = []
    
    # Process each line
    for i, line in enumerate(lines):
        line_stripped = line.strip()
        
        # Check if this line contains a JSON key-value pair
        if line_stripped.startswith('"') and '":' in line_stripped:
            # Extract key from line using regex to handle complex cases
            match = re.match(r'^\s*"([^"]*)":\s*', line)
            if match:
                key = match.group(1)
                if key in seen_keys:
                    duplicates.append((i+1, key))
                    print(f"Line {i+1}: Skipping duplicate key '{key}'")
                    continue  # Skip this duplicate line
                else:
                    seen_keys.add(key)
        
        clean_lines.append(line)
    
    if duplicates:
        print(f"\nFound and removed {len(duplicates)} duplicate key occurrences")
        
        # Join the cleaned lines
        clean_content = '\n'.join(clean_lines)
        
        # Fix trailing comma issues by removing trailing commas before closing braces
        clean_content = re.sub(r',(\s*})', r'\1', clean_content)
        
        # Validate the cleaned JSON
        try:
            parsed = json.loads(clean_content)
            print("✓ Cleaned JSON is valid")
            print(f"✓ Total unique keys: {len(parsed)}")
            return clean_content
        except json.JSONDecodeError as e:
            print(f"✗ Error in cleaned JSON: {e}")
            
            # Try to fix more JSON issues
            print("Attempting additional JSON fixes...")
            
            # Remove any remaining trailing commas
            clean_content = re.sub(r',(\s*[}\]])', r'\1', clean_content)
            
            # Try parsing again
            try:
                parsed = json.loads(clean_content)
                print("✓ JSON fixed and is now valid")
                print(f"✓ Total unique keys: {len(parsed)}")
                return clean_content
            except json.JSONDecodeError as e2:
                print(f"✗ Still cannot parse JSON: {e2}")
                return None
    else:
        print("No duplicate keys found")
        return content

if __name__ == "__main__":
    file_path = "src/lib/i18n/locales/he-IL/translation.json"
    
    print("Analyzing Hebrew translation file for duplicate keys...")
    
    cleaned_content = remove_duplicate_keys(file_path)
    
    if cleaned_content:
        # Write the cleaned content back
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(cleaned_content)
        print(f"\n✓ Successfully removed duplicates and updated {file_path}")
    else:
        print("✗ Failed to clean the file") 