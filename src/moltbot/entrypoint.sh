#!/bin/bash
# MoltBot Azure Container Apps Entrypoint
# Generates configuration from environment variables and starts the gateway

set -e

CONFIG_DIR="${HOME}/.moltbot"
CONFIG_FILE="${CONFIG_DIR}/moltbot.json"

# Create config directory
mkdir -p "${CONFIG_DIR}"

# Build Discord config section if token is provided
DISCORD_CONFIG=""
if [ -n "${DISCORD_BOT_TOKEN}" ]; then
  # Parse comma-separated Discord user IDs into JSON array format
  if [ -n "${DISCORD_ALLOWED_USERS}" ]; then
    # Convert "id1,id2,id3" to ["id1","id2","id3"]
    DISCORD_USERS_JSON=$(echo "${DISCORD_ALLOWED_USERS}" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
    DISCORD_DM_CONFIG='"dm": {
        "enabled": true,
        "policy": "allowlist",
        "allowFrom": '"${DISCORD_USERS_JSON}"'
      }'
    echo "Discord channel configured: yes (DM allowlist: ${DISCORD_ALLOWED_USERS})"
  else
    # No allowlist - disable DMs for security
    DISCORD_DM_CONFIG='"dm": {
        "enabled": false
      }'
    echo "Discord channel configured: yes (DMs disabled - set DISCORD_ALLOWED_USERS to enable)"
  fi
  DISCORD_CONFIG='"discord": {
      "enabled": true,
      '"${DISCORD_DM_CONFIG}"',
      "groupPolicy": "open"
    }'
else
  echo "Discord channel configured: no (DISCORD_BOT_TOKEN not set)"
fi

# Build Telegram config section if token is provided
TELEGRAM_CONFIG=""
if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
  if [ -n "${TELEGRAM_ALLOWED_USER_ID}" ]; then
    TELEGRAM_USERS_JSON=$(echo "${TELEGRAM_ALLOWED_USER_ID}" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/' )
    TELEGRAM_ALLOW_CONFIG='"allowFrom": '"${TELEGRAM_USERS_JSON}"''
    echo "Telegram channel configured: yes (allowlist: ${TELEGRAM_ALLOWED_USER_ID})"
  else
    TELEGRAM_ALLOW_CONFIG='"allowFrom": []'
    echo "Telegram channel configured: yes (allowlist: none)"
  fi
  TELEGRAM_CONFIG='"telegram": {
      "enabled": true,
      "botToken": "'"${TELEGRAM_BOT_TOKEN}"'",
      '"${TELEGRAM_ALLOW_CONFIG}"'
    }'
else
  echo "Telegram channel configured: no (TELEGRAM_BOT_TOKEN not set)"
fi

# Build channels section
CHANNELS_SECTION=""
CHANNELS_ENTRIES=""
if [ -n "${DISCORD_CONFIG}" ]; then
  CHANNELS_ENTRIES="${DISCORD_CONFIG}"
fi
if [ -n "${TELEGRAM_CONFIG}" ]; then
  if [ -n "${CHANNELS_ENTRIES}" ]; then
    CHANNELS_ENTRIES="${CHANNELS_ENTRIES}, ${TELEGRAM_CONFIG}"
  else
    CHANNELS_ENTRIES="${TELEGRAM_CONFIG}"
  fi
fi
if [ -n "${CHANNELS_ENTRIES}" ]; then
  CHANNELS_SECTION='"channels": {
    '"${CHANNELS_ENTRIES}"'
  },'
fi

# Resolve gateway token from either MOLTBOT_GATEWAY_TOKEN or CLAWDBOT_GATEWAY_TOKEN
GATEWAY_TOKEN_VALUE="${MOLTBOT_GATEWAY_TOKEN}"
if [ -z "${GATEWAY_TOKEN_VALUE}" ] && [ -n "${CLAWDBOT_GATEWAY_TOKEN}" ]; then
  GATEWAY_TOKEN_VALUE="${CLAWDBOT_GATEWAY_TOKEN}"
fi

# Resolve the model reference
FULL_MODEL="${MOLTBOT_MODEL:-${CLAWDBOT_MODEL:-openai/gpt-4o-mini}}"

# If model has no provider prefix (no slash), use the openai provider so the
# OpenAI SDK picks up OPENAI_BASE_URL (which points to Azure) automatically.
if ! echo "${FULL_MODEL}" | grep -q '/'; then
  MODEL_ID="${FULL_MODEL}"
  FULL_MODEL="openai/${MODEL_ID}"
  echo "No provider prefix in model '${MODEL_ID}' — using openai/${MODEL_ID}"
else
  MODEL_ID=$(echo "${FULL_MODEL}" | cut -d'/' -f2-)
fi

MODEL_PROVIDER=$(echo "${FULL_MODEL}" | cut -d'/' -f1)
echo "Model: ${FULL_MODEL} (provider=${MODEL_PROVIDER}, id=${MODEL_ID})"

# Build custom provider config when an Azure OpenAI endpoint is in use.
# MoltBot's built-in openai provider ignores OPENAI_BASE_URL, so we override
# the provider in the config to redirect calls to the Azure endpoint.
MODELS_SECTION=""
if echo "${OPENAI_BASE_URL}" | grep -qi "cognitiveservices\|openai\.azure"; then
  AZURE_BASE="${OPENAI_BASE_URL%/}"
  # Normalise to .../openai/v1
  case "${AZURE_BASE}" in
    */openai/v1) ;;
    */openai)    AZURE_BASE="${AZURE_BASE}/v1" ;;
    *)           AZURE_BASE="${AZURE_BASE}/openai/v1" ;;
  esac

  PROVIDER_NAME="${MODEL_PROVIDER}"

  echo "Overriding '${PROVIDER_NAME}' provider → baseUrl=${AZURE_BASE}"
  MODELS_SECTION='"models": {
    "providers": {
      "'"${PROVIDER_NAME}"'": {
        "baseUrl": "'"${AZURE_BASE}"'",
        "apiKey": "'"${OPENAI_API_KEY}"'",
        "api": "openai-completions",
        "authHeader": false,
        "headers": {
          "api-key": "'"${OPENAI_API_KEY}"'"
        },
        "models": [
          {
            "id": "'"${MODEL_ID}"'",
            "name": "'"${MODEL_ID}"'",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 128000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },'
fi

# Generate MoltBot configuration using current schema format
cat > "${CONFIG_FILE}" << EOF
{
  "agents": {
    "defaults": {
      "workspace": "${HOME}/molt",
      "model": {
        "primary": "${FULL_MODEL}"
      }
    },
    "list": [
      {
        "id": "main",
        "identity": {
          "name": "${MOLTBOT_PERSONA_NAME:-Molt}",
          "theme": "helpful assistant",
          "emoji": "🦞"
        }
      }
    ]
  },
  ${MODELS_SECTION}
  ${CHANNELS_SECTION}
  "gateway": {
    "mode": "local",
    "port": ${GATEWAY_PORT:-18789},
    "bind": "lan",
    "controlUi": {
      "enabled": true,
      "allowedOrigins": ["https://${CONTAINER_APP_FQDN:-localhost}"]
    },
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN_VALUE}"
    }
  },
  "logging": {
    "level": "info",
    "consoleLevel": "info",
    "consoleStyle": "pretty"
  }
}
EOF

echo "MoltBot configuration written to ${CONFIG_FILE}"
echo "Gateway token configured: $([ -n "${GATEWAY_TOKEN_VALUE}" ] && echo 'yes' || echo 'no')"

# Export OPENCLAW_GATEWAY_TOKEN so the gateway binary picks it up
if [ -n "${GATEWAY_TOKEN_VALUE}" ]; then
  export OPENCLAW_GATEWAY_TOKEN="${GATEWAY_TOKEN_VALUE}"
fi

# Auto-apply doctor fixes (enable channels, migrate config, etc.)
echo "Running openclaw doctor --fix..."
node dist/index.js doctor --fix || true

# Start MoltBot Gateway with --allow-unconfigured to allow running without messaging channels
exec node dist/index.js gateway --bind lan --port "${GATEWAY_PORT:-18789}" --allow-unconfigured "$@"