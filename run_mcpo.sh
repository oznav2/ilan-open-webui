#!/bin/bash
set -e

# הגדרת כל התיקיות של ה-cache וה-HOME ל-/app כדי למנוע בעיות הרשאות
export HOME=/app
export UV_CACHE_DIR=/app/.cache/uv
export NPM_CONFIG_CACHE=/app/.npm

date_str=$(date +"%d%m%Y_%H%M%S")
log_file="/app/logs/mcpo_${date_str}.log"

# Check if /app/data exists and is not empty
if [ -d "/app/data" ] && [ "$(ls -A /app/data)" ]; then
  echo "/app/data already exists and is not empty. Skipping creation to avoid overwriting existing data."
else
  echo "/app/data does not exist or is empty. Creating directory..."
  mkdir -p /app/data
fi

# התקנת כלים MCP באופן דינמי על פי הגדרות ב-config.json
if [ -f /app/config/config.json ]; then
  echo "זוהה /app/config/config.json, מתכונן להתקין כלים MCP בצורה דינמית..."
  jq -r '.mcpServers | keys[]' /app/config/config.json | while read -r key; do
    (
      command=$(jq -r ".mcpServers[\"$key\"].command" /app/config/config.json)
      args=$(jq -r ".mcpServers[\"$key\"].args | @sh" /app/config/config.json)
      envs=$(jq -r ".mcpServers[\"$key\"].env // {} | to_entries[]? | \"export \(.key)=\\\"\(.value)\\\"\"" /app/config/config.json)
      # הגדרת משתני סביבה
      if [ -n "$envs" ]; then
        eval "$envs"
      fi
      # התקנת כלים MCP באופן דינמי
      if [ "$command" = "uvx" ]; then
        echo "שימוש ב-uvx להתקין: $args"
        eval uvx $args
      elif [ "$command" = "npx" ]; then
        echo "שימוש ב-npx להתקין: $args"
        eval npx $args
      else
        echo "לא ידוע command: $command, דלקת $key"
      fi
    )
  done
else
  echo "לא זוהה /app/config/config.json, דלקת התקין כלים MCP בצורה דינמית."
fi

# התחלת שירות הראשי 
if [ ! -z "$MCPO_API_KEY" ]; then
  uvx mcpo --host 0.0.0.0 --port 8888 --config /app/config/config.json --api-key "$MCPO_API_KEY" 2>&1 | tee -a "$log_file"
else
  uvx mcpo --host 0.0.0.0 --port 8888 --config /app/config/config.json 2>&1 | tee -a "$log_file"
fi