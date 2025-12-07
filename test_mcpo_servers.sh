#!/bin/bash

# MCP service base URL
BASE_URL="http://localhost:8888"

# List of tools (based on config.json)
TOOLS=("fetch" "sequential-thinking" "memory" "time" "calculator" "airbnb" "json" "File System" "context7" "perplexity-mcp" "Playwright" "quillopy" "n8n-local" "github" "mcp-git-ingest" "git" "duckduckgo" "brave-search" "tavily-mcp" "MCP_DOCKER")

echo "==== Automated Testing of MCP Tool Basic Functionality ===="
echo "Service Base URL: $BASE_URL"
echo

for tool in "${TOOLS[@]}"; do
  echo "---- Testing $tool ----"
  # 1. OpenAPI documentation accessibility
  echo -n "  [1] /$tool/docs accessibility: "
  if curl -s -f "$BASE_URL/$tool/docs" > /dev/null; then
    echo "✅"
  else
    echo "❌ (Unable to access OpenAPI documentation)"
  fi

  # 2. Typical interface functionality (e.g., POST /query or /search, parameters need to be adjusted based on actual API)
  if [[ "$tool" == "brave-search" || "$tool" == "tavily-mcp" ]]; then
    echo -n "  [2] /$tool/query or /$tool/search functionality: "
    # Attempt POST /query
    if curl -s -f -X POST "$BASE_URL/$tool/query" -H "Content-Type: application/json" -d '{"q":"test"}' > /dev/null; then
      echo "✅ (POST /query)"
    elif curl -s -f -X POST "$BASE_URL/$tool/search" -H "Content-Type: application/json" -d '{"q":"test"}' > /dev/null; then
      echo "✅ (POST /search)"
    else
      echo "❌ (No response or error from the interface)"
    fi
  elif [[ "$tool" == "fetch" ]]; then
    echo -n "  [2] /$tool/fetch functionality: "
    if curl -s -f -X POST "$BASE_URL/$tool/fetch" -H "Content-Type: application/json" -d '{"url":"https://www.example.com"}' > /dev/null; then
      echo "✅"
    else
      echo "❌ (No response or error from the interface)"
    fi
  else
    echo "  [2] No typical interface test defined"
  fi

  # 3. Error handling test
  echo -n "  [3] Error parameter handling: "
  if curl -s -f -X POST "$BASE_URL/$tool/query" -H "Content-Type: application/json" -d '{"bad":"param"}' | grep -q "error"; then
    echo "✅ (Error message detected)"
  else
    echo "⚠️ (No error message detected, manual inspection required)"
  fi

  echo
done

echo "==== Testing Complete ===="
echo "If there are ❌ or ⚠️ items, please check the service logs and troubleshoot according to readme-docker.md."