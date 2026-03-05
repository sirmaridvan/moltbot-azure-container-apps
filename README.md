# 🦞 MoltBot on Azure Container Apps

Deploy your personal AI assistant to Azure Container Apps with Telegram integration. This sample shows how to run [MoltBot](https://molt.bot) - an open-source personal AI assistant - on Azure's serverless container platform.

## What You'll Get

- 🦞 **MoltBot AI Assistant** running on Azure Container Apps
- 💬 **Telegram Integration** - Chat with your AI via Telegram DMs
- 🧠 **Azure AI Foundry** - Enterprise-grade LLM access with managed model deployments
- 🔐 **Secure by Default** - Gateway token authentication + DM allowlist + automatic HTTPS
- 📊 **Azure Monitoring** - Full observability via Log Analytics
- 💾 **Persistent Storage** - Azure Storage for data that survives restarts

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Azure Resource Group                               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                  Azure Container Apps Environment                       ││
│  │                                                                         ││
│  │  ┌───────────────────────────────────────────────────────────────────┐  ││
│  │  │                    🦞 MoltBot Container App                       │  ││
│  │  │                                                                    │  ││
│  │  │  • Gateway (port 18789)          • Telegram Bot Connection        │  ││
│  │  │  • Control UI (web chat)         • Azure AI Foundry Integration   │  ││
│  │  │  • Dynamic Config Generation     • DM Allowlist Security          │  ││
│  │  │  • Skills & Automation           • Persistent Memory              │  ││
│  │  └───────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │  📦 Container       │  │   💾 Storage        │  │  📊 Log Analytics  │ │
│  │     Registry        │  │     Account         │  │                     │ │
│  │  Stores MoltBot    │  │  Persistent data    │  │  Logs & metrics    │ │
│  │  container image    │  │  for sessions       │  │  for monitoring    │ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- ✅ Azure subscription with Contributor access
- ✅ [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed
- ✅ [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
- ✅ [Azure AI Foundry](https://ai.azure.com) model deployment + API key
- ✅ Telegram account for bot creation

## One-Click Deployment with azd

The fastest way to deploy MoltBot is using Azure Developer CLI (`azd`). This provisions all infrastructure, builds the container image, and deploys everything in one command.

### Step 1: Create Your Telegram Bot (Do This First!)

**⚠️ Important:** Do this before running `azd up` — you'll need the bot token during deployment.

1. Open Telegram and start a chat with **@BotFather**
2. Send `/newbot` and follow the prompts
3. Copy the **bot token** (save it securely!)
4. Start a chat with your new bot and send `hello`
5. Get your **Telegram User ID** (use @userinfobot or @getmyid_bot)

> **🔐 Security Note:** The Telegram User ID is used for the allowlist. Only users in this list can message your bot.

### Step 2: Provision Infrastructure

```bash
# Clone this sample
git clone https://github.com/BandaruDheeraj/moltbot-azure-container-apps.git
cd moltbot-azure-container-apps

# Login to Azure
azd auth login

# Provision infrastructure (creates ACR, Container Apps Environment, etc.)
azd provision
```

When prompted, enter:
- **Environment name**: e.g., `MoltBot-prod`
- **Azure subscription**: Select your subscription
- **Location**: e.g., `eastus2`

> **Note:** `azd provision` creates the Azure infrastructure without deploying the app. We need to build the image first.

This creates:

| Step | What Happens |
|:----:|--------------|
| 1️⃣ | Creates a Resource Group |
| 2️⃣ | Deploys Azure Container Registry |
| 3️⃣ | Sets up Azure Storage for persistent data |
| 4️⃣ | Creates a Container Apps Environment |
| 5️⃣ | Configures Log Analytics for monitoring |

### Step 3: Build the Container Image

**⚠️ Required before deploying.** The container image must exist in ACR first.

```bash
# Get your ACR name
ACR_NAME=$(az acr list --resource-group rg-MoltBot-prod --query "[0].name" -o tsv)

# Build the image in Azure (no local Docker needed!)
az acr build --registry $ACR_NAME --image "MoltBot:latest" --file src/MoltBot/Dockerfile src/MoltBot/
```

**Understanding this command:**

| Part | What It Does |
|------|--------------|
| `--registry $ACR_NAME` | Build in your Azure Container Registry (in the cloud) |
| `--image "MoltBot:latest"` | Name the output image `MoltBot:latest` (we choose this name) |
| `--file src/MoltBot/Dockerfile` | Use the Dockerfile from our sample repo |
| `src/MoltBot/` | Send this folder as the build context |

This takes about 3-5 minutes. The Dockerfile automatically:
1. Starts from a Node.js base image
2. Clones the official [MoltBot source](https://github.com/MoltBot/MoltBot) from GitHub
3. Installs dependencies with pnpm
4. Builds the TypeScript application
5. Builds the Control UI
6. Adds our custom `entrypoint.sh` that generates config from Azure environment variables

> **Note:** You don't need to download MoltBot separately - it's pulled fresh during the build. The resulting image is stored in your ACR as `MoltBot:latest`.

### Step 4: Configure Your Credentials

```bash
# Set your required secrets
azd env set OPENAI_API_KEY "your-azure-ai-foundry-key"
azd env set OPENAI_BASE_URL "https://<your-foundry-endpoint>"
azd env set TELEGRAM_BOT_TOKEN "your-telegram-bot-token"
azd env set TELEGRAM_ALLOWED_USER_ID "your-telegram-user-id"
```

**Where to get these values:**

| Variable | Where to Get It |
|----------|-----------------|
| `OPENAI_API_KEY` | Azure AI Foundry → Your project → Model endpoint → API key |
| `OPENAI_BASE_URL` | Azure AI Foundry → Your project → Model endpoint URL |
| `TELEGRAM_BOT_TOKEN` | Telegram → @BotFather → `/newbot` |
| `TELEGRAM_ALLOWED_USER_ID` | Telegram → @userinfobot or @getmyid_bot |

**Optional settings:**

```bash
# Change the AI model (use your Azure AI Foundry deployment name)
azd env set MOLTBOT_MODEL "gpt-5-mini"

# Change the bot's name
azd env set MOLTBOT_PERSONA_NAME "Clawd"

# Add IP restrictions (for security)
azd env set ALLOWED_IP_RANGES "1.2.3.4/32"

# Enable email alerts
azd env set ALERT_EMAIL_ADDRESS "your-email@example.com"
```

### Step 5: Deploy the Application

```bash
azd deploy
```

This deploys MoltBot to Container Apps with all your secrets configured.

> **⚠️ Important:** If you change any environment variables later, run `azd deploy` again to apply them.

### Step 6: Start Chatting! 🎉

1. Open Telegram and search for your bot by username
2. Tap **Start** to begin a chat
3. Send: `Hello!`
4. Wait a few seconds for the response

### What Gets Deployed

| Resource | Purpose |
|----------|---------|
| Azure Container Registry | Stores your MoltBot container image |
| Container Apps Environment | Hosting platform with built-in scaling |
| MoltBot Container App | Your AI assistant (1 CPU, 2GB RAM) |
| Managed Identity | Secure passwordless access to ACR |
| Log Analytics Workspace | Logs and monitoring |
| Storage Account | Persistent data storage |

### Updating After Deployment

```bash
# Change configuration (e.g., add another Telegram user)
azd env set TELEGRAM_ALLOWED_USER_ID "user-id-1,user-id-2"
azd deploy

# Rebuild image with latest MoltBot
az acr build --registry $ACR_NAME --image "MoltBot:latest" --file src/MoltBot/Dockerfile src/MoltBot/
azd deploy
```

---

## Adding More Telegram Users

To allow additional Telegram users to chat with your bot:

```bash
azd env set TELEGRAM_ALLOWED_USER_ID "user-id-1,user-id-2"  # Comma-separated for multiple users
azd deploy
```

Get each user's Telegram ID via @userinfobot or @getmyid_bot.

---

## Manual Deployment (Alternative)

If you prefer to deploy step-by-step without `azd`, follow these instructions:

### Step 1: Create Azure Resources

```bash
# Variables - customize these
RESOURCE_GROUP="rg-MoltBot"
LOCATION="eastus2"
ENVIRONMENT_NAME="cae-MoltBot"
ACR_NAME="crMoltBot$(openssl rand -hex 4)"  # Must be globally unique
IDENTITY_NAME="MoltBot-identity"
APP_NAME="MoltBot"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic

# Create User-Assigned Managed Identity
az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME

# Get identity details
IDENTITY_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query id -o tsv)
IDENTITY_CLIENT_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query clientId -o tsv)
IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query principalId -o tsv)

# Grant identity access to ACR
ACR_ID=$(az acr show --resource-group $RESOURCE_GROUP --name $ACR_NAME --query id -o tsv)
az role assignment create --assignee $IDENTITY_PRINCIPAL_ID --role AcrPull --scope $ACR_ID

# Create Container Apps Environment
az containerapp env create \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### Step 2: Build MoltBot Image

MoltBot must be built from source. We use Azure Container Registry Tasks (no local Docker required):

```bash
# Build the image in ACR (runs in the cloud)
az acr build \
  --registry $ACR_NAME \
  --image "MoltBot:v1" \
  --file src/MoltBot/Dockerfile \
  src/MoltBot/
```

This takes about 5 minutes. The build:
1. Clones MoltBot from GitHub
2. Installs dependencies with pnpm
3. Builds the TypeScript application
4. Builds the Control UI
5. Copies our custom `entrypoint.sh` for Azure configuration

### Step 3: Create Telegram Bot

1. Open Telegram and start a chat with **@BotFather**
2. Send `/newbot` and follow the prompts
3. Copy the **bot token** (save it securely!)
4. Get your **Telegram User ID** (use @userinfobot or @getmyid_bot)

### Step 4: Generate Gateway Token

```bash
# Generate a secure random token for gateway authentication
GATEWAY_TOKEN=$(openssl rand -hex 16)
echo "Gateway Token: $GATEWAY_TOKEN"
# Save this! You'll need it for the Control UI
```

### Step 5: Create Container App with Secrets

```bash
# Set your actual values here
OPENAI_API_KEY="your-azure-ai-foundry-key"
OPENAI_BASE_URL="https://<your-foundry-endpoint>"
TELEGRAM_BOT_TOKEN="your-telegram-bot-token"
TELEGRAM_USER_ID="your-telegram-user-id"

# Create the Container App with secrets
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT_NAME \
  --image "${ACR_NAME}.azurecr.io/MoltBot:v1" \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-identity $IDENTITY_ID \
  --user-assigned $IDENTITY_ID \
  --target-port 18789 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 1 \
  --cpu 1.0 \
  --memory 2Gi \
  --secrets \
    "openai-api-key=$OPENAI_API_KEY" \
    "telegram-bot-token=$TELEGRAM_BOT_TOKEN" \
    "gateway-token=$GATEWAY_TOKEN" \
  --env-vars \
    "OPENAI_API_KEY=secretref:openai-api-key" \
    "OPENAI_BASE_URL=$OPENAI_BASE_URL" \
    "TELEGRAM_BOT_TOKEN=secretref:telegram-bot-token" \
    "MOLTBOT_GATEWAY_TOKEN=secretref:gateway-token" \
    "TELEGRAM_ALLOWED_USER_ID=$TELEGRAM_USER_ID" \
    "MOLTBOT_MODEL=gpt-5-mini" \
    "MOLTBOT_PERSONA_NAME=Clawd" \
    "GATEWAY_PORT=18789" \
    "NODE_ENV=production"
```

### Step 6: Get Your Bot URL

```bash
# Get the Container App URL
az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv
```

## Testing Your Bot

### Via Telegram

1. Open Telegram and search for your bot by username
2. Tap **Start** to begin a chat
3. Send: `Hello!`
4. Wait a few seconds for the response

### Via Control UI (Web Chat)

The Control UI is available but shows "pairing required" by default. Telegram DMs are the primary interface.

To access the Control UI:
```
https://<your-app-url>/?token=<your-gateway-token>
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | ✅ | Azure AI Foundry API key for LLM access |
| `OPENAI_BASE_URL` | ✅ | Azure AI Foundry model endpoint URL |
| `TELEGRAM_BOT_TOKEN` | ✅ | Telegram bot token from @BotFather |
| `TELEGRAM_ALLOWED_USER_ID` | ✅ | Your Telegram user ID (DM allowlist) |
| `MOLTBOT_GATEWAY_TOKEN` | ✅ | Random token for gateway authentication (auto-generated if not set) |
| `MOLTBOT_MODEL` | No | Azure AI Foundry deployment name (default: `gpt-5-mini`) |
| `MOLTBOT_PERSONA_NAME` | No | Bot name (default: `Clawd`) |

### Security Parameters (azd)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ALLOWED_IP_RANGES` | (empty) | Comma-separated CIDR blocks allowed to access the gateway (e.g., `1.2.3.4/32,10.0.0.0/8`) |
| `INTERNAL_ONLY` | `false` | Deploy with no public ingress (VNet-only access) |
| `ENABLE_ALERTS` | `true` | Deploy Azure Monitor alerts for security events |
| `ALERT_EMAIL_ADDRESS` | (empty) | Email for alert notifications |

**Enable IP restrictions:**
```bash
azd env set ALLOWED_IP_RANGES "1.2.3.4/32"
azd deploy
```

**Enable email alerts:**
```bash
azd env set ALERT_EMAIL_ADDRESS "security@example.com"
azd deploy
```

### Supported Models (via Azure AI Foundry)

You can use any model you deploy in Azure AI Foundry. The value of `MOLTBOT_MODEL` must match your **deployment name** exactly.

| Model | Deployment Name (Example) | Notes |
|-------|---------------------------|-------|
| GPT-5 mini | `gpt-5-mini` | **Recommended** — fast, cost-effective (default) |
| GPT-4o mini | `gpt-4o-mini` | Previous generation, still solid |
| GPT-4o | `gpt-4o` | Higher quality |
| GPT-4.1 | `gpt-4.1` | Strong reasoning |

Change model:
```bash
azd env set MOLTBOT_MODEL "<your-foundry-deployment-name>"
azd deploy
```

> **⚠️ Important:** The deployment name must match exactly (case-sensitive). The entrypoint auto-prefixes bare model names — if you set `MOLTBOT_MODEL=gpt-5-mini`, it becomes `openai/gpt-5-mini`.

### Custom Persona

Change your bot's personality:
```bash
azd env set MOLTBOT_PERSONA_NAME "Jarvis"
azd deploy
```

### How the Entrypoint Works

The `entrypoint.sh` script dynamically generates MoltBot's configuration from environment variables at container startup:

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "openai/gpt-5-mini" }
    },
    "list": [{ "id": "main", "identity": { "name": "Clawd" } }]
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dm": { "policy": "allowlist", "allowFrom": ["your-user-id"] }
    }
  },
  "gateway": {
    "auth": { "mode": "token", "token": "<your-gateway-token>" }
  }
}
```

The entrypoint script also:
- **Detects Azure OpenAI endpoints** and overrides the provider config with the correct base URL and `api-key` auth header (since MoltBot's built-in OpenAI provider ignores `OPENAI_BASE_URL`)
- **Auto-prefixes bare model names** — if you set `MOLTBOT_MODEL=gpt-5-mini`, it becomes `openai/gpt-5-mini`

This approach:
- Keeps secrets out of the container image
- Allows configuration changes without rebuilding
- Generates proper MoltBot JSON config format
- Handles Azure AI Foundry routing automatically

## Updating Your Bot

### Update Configuration

```bash
# Change model
az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --set-env-vars "MOLTBOT_MODEL=gpt-4o"

# Add another allowed Telegram user
az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --set-env-vars "TELEGRAM_ALLOWED_USER_ID=user1-id,user2-id"
```

### Update Secrets

```bash
# Update API key
az containerapp secret set --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --secrets "openai-api-key=your-new-key"

# Restart to apply secret changes
REVISION=$(az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "properties.latestRevisionName" -o tsv)
az containerapp revision restart --name $APP_NAME --resource-group $RESOURCE_GROUP --revision $REVISION
```

### Update MoltBot Version

```bash
# Rebuild with latest MoltBot
az acr build --registry $ACR_NAME --image "MoltBot:v2" \
  --file src/MoltBot/Dockerfile src/MoltBot/

# Deploy new image
az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --image "${ACR_NAME}.azurecr.io/MoltBot:v2"
```

## Monitoring

### View Logs

```bash
# Stream live logs
az containerapp logs show --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --follow --tail 50 --type console

# Check for errors
az containerapp logs show --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --tail 100 --type console | grep -i error
```

### What to Look For

✅ **Healthy startup:**
```
Telegram channel configured: yes (allowlist: 123456789)
MoltBot configuration written to /home/node/.MoltBot/MoltBot.json
Gateway token configured: yes
[telegram] connected
[gateway] agent model: openai/gpt-5-mini
[gateway] listening on ws://0.0.0.0:18789
```

❌ **Common errors:**
- `Unknown model: ...` - Model name must match your Azure AI Foundry deployment name exactly
- `HTTP 401: authentication_error` - Invalid API key or requests hitting wrong endpoint
- `[telegram] channel exited` - Invalid Telegram bot token

## Troubleshooting

### Container Image Not Found (MANIFEST_UNKNOWN)

**Problem:** Logs show `MANIFEST_UNKNOWN: manifest tagged by "latest" is not found`

**Cause:** The container image wasn't built before deployment.

**Solution:** Build the image manually:
```bash
ACR_NAME=$(az acr list --resource-group rg-MoltBot-prod --query "[0].name" -o tsv)
az acr build --registry $ACR_NAME --image "MoltBot:latest" --file src/MoltBot/Dockerfile src/MoltBot/
azd deploy
```

### Windows Line Endings Breaking entrypoint.sh

**Problem:** Logs show `exec /app/entrypoint.sh: no such file or directory`

**Cause:** Windows CRLF line endings in shell scripts break Linux containers.

**Solution:** Convert to Unix line endings before building:
```powershell
# PowerShell - convert CRLF to LF
$content = Get-Content src/MoltBot/entrypoint.sh -Raw
$content -replace "`r`n", "`n" | Set-Content src/MoltBot/entrypoint.sh -NoNewline
```

Then rebuild the image:
```bash
az acr build --registry $ACR_NAME --image "MoltBot:latest" --file src/MoltBot/Dockerfile src/MoltBot/
```

### Secrets Not Applied (Telegram Unauthorized)

**Problem:** Logs show Telegram auth errors or the bot never connects.

**Cause:** `azd env set` stores values locally, but they weren't applied to the container.

**Solution:** Manually set secrets on the container app:
```bash
RESOURCE_GROUP="rg-MoltBot-prod"
APP_NAME="MoltBot"

az containerapp secret set --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --secrets "telegram-bot-token=YOUR_ACTUAL_TOKEN"

az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --set-env-vars "TELEGRAM_ALLOWED_USER_ID=YOUR_TELEGRAM_USER_ID"

# Restart to apply
REVISION=$(az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP \
  --query "properties.latestRevisionName" -o tsv)
az containerapp revision restart --name $APP_NAME --resource-group $RESOURCE_GROUP --revision $REVISION
```

### "Unknown model" Error

**Problem:** MoltBot logs show `Unknown model: <your-model>`

**Cause:** The model name must match your **Azure AI Foundry deployment name** exactly.

**Solution:**
```bash
azd env set MOLTBOT_MODEL "<your-foundry-deployment-name>"
azd deploy
```

### HTTP 401 Authentication Error

**Problem:** Logs show `HTTP 401: authentication_error` or `Incorrect API key provided`

**Cause:** This can happen for two reasons:
1. Invalid or expired API key
2. **Requests hitting `api.openai.com` instead of your Azure endpoint** — MoltBot's built-in OpenAI provider ignores the `OPENAI_BASE_URL` environment variable. Our entrypoint script works around this by overriding the provider config when it detects an Azure endpoint.

**Solution:**
```bash
# 1. Check the logs to see which URL is being called
az containerapp logs show --name MoltBot --resource-group rg-MoltBot-prod --tail 50 \
  | grep -i "url\|401\|error"

# 2. If logs show api.openai.com — ensure OPENAI_BASE_URL contains your Azure endpoint
azd env set OPENAI_BASE_URL "https://<your-resource>.cognitiveservices.azure.com/openai/v1/"

# 3. If the key itself is wrong — update it
azd env set OPENAI_API_KEY "your-actual-key"

# 4. Redeploy
azd deploy
```

> **💡 How does the fix work?** The entrypoint detects `cognitiveservices` or `openai.azure` in `OPENAI_BASE_URL` and automatically overrides the provider in MoltBot's JSON config with your Azure base URL and `api-key` authentication header.

### Bot Doesn't Respond on Telegram

**Problem:** Bot is online but ignores your messages.

**Cause:** Your Telegram user ID isn't in the allowlist.

**Solution:**
```bash
azd env set TELEGRAM_ALLOWED_USER_ID "your-telegram-user-id"
azd deploy
```

### Container Won't Start

1. Check if image exists:
   ```bash
   az acr repository show-tags --name $ACR_NAME --repository MoltBot
   ```

2. Verify managed identity has ACR pull permission:
   ```bash
   az role assignment list --assignee $IDENTITY_PRINCIPAL_ID --scope $ACR_ID
   ```

## Security

This deployment addresses common security concerns raised by the community:

### Security Features Included

| Concern | How ACA Addresses It | Configuration |
|---------|---------------------|---------------|
| **1. Close ports / IP allowlist** | ✅ Built-in IP restrictions on ingress | `ALLOWED_IP_RANGES` parameter |
| **2. Auth (JWT/OAuth/strong secret + TLS)** | ✅ Gateway token auth + automatic HTTPS | `MOLTBOT_GATEWAY_TOKEN` + free TLS certs |
| **3. Rotate keys (assume compromise)** | ✅ Container App secrets + easy rotation | `az containerapp secret set` |
| **4. Rate limiting + logs + alerts** | ✅ Log Analytics + Azure Monitor alerts | Preconfigured alerts included |

### Preconfigured Security Alerts

The deployment includes four Azure Monitor alerts (enabled by default):

| Alert | Trigger | Indicates |
|-------|---------|-----------|
| **High Error Rate** | >10 auth errors in 5 min | Brute force attack |
| **Container Restarts** | >3 restarts in 15 min | Crash or OOM attack |
| **Unusual Activity** | >100 messages/hour | Abuse |
| **Channel Disconnect** | Telegram goes offline | Token issue |

### Enable IP Restrictions

Restrict who can access your MoltBot gateway:

```bash
# Only allow specific IPs (e.g., your home + VPN)
azd env set ALLOWED_IP_RANGES "1.2.3.4/32,10.0.0.0/8"
azd deploy
```

### Enable Internal-Only Access

For maximum security, deploy with no public ingress:

```bash
azd env set INTERNAL_ONLY "true"
azd deploy
```

This makes MoltBot accessible only from within your Azure VNet.

### Key Rotation

Rotate API keys without rebuilding:

```bash
# Rotate Azure AI Foundry API key
az containerapp secret set --name MoltBot --resource-group $RESOURCE_GROUP \
  --secrets "openai-api-key=your-new-key-here"

# Rotate Telegram bot token
az containerapp secret set --name MoltBot --resource-group $RESOURCE_GROUP \
  --secrets "telegram-bot-token=new-telegram-token"

# Rotate gateway token
az containerapp secret set --name MoltBot --resource-group $RESOURCE_GROUP \
  --secrets "gateway-token=new-32-char-secret"

# Restart to apply
REVISION=$(az containerapp show --name MoltBot --resource-group $RESOURCE_GROUP \
  --query "properties.latestRevisionName" -o tsv)
az containerapp revision restart --name MoltBot --resource-group $RESOURCE_GROUP \
  --revision $REVISION
```

**Rotation best practices:**
- Rotate API keys monthly or after any suspected exposure
- Use Azure Key Vault for automated rotation (optional)
- Monitor for failed auth attempts (covered by alerts above)

### Defense in Depth Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────────┐                                                      │
│   │ 1. IP RESTRICT  │  Only allowed IPs can reach the gateway              │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 2. TLS/HTTPS    │  All traffic encrypted with auto-renewed certs      │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 3. DM ALLOWLIST │  Only your Telegram user ID can message the bot     │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 4. GATEWAY AUTH │  Token required for Control UI access               │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 5. SECRETS MGMT │  API keys stored as Container App secrets           │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 6. MANAGED ID   │  Passwordless auth to Azure services (ACR)          │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 7. HYPER-V      │  Container isolation at hardware level              │
│   └────────┬────────┘                                                      │
│            ▼                                                               │
│   ┌─────────────────┐                                                      │
│   │ 8. ALERTS       │  Notify on auth failures, restarts, abuse           │
│   └─────────────────┘                                                      │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Implementation Checklist

| Practice | How to Implement | Why It Matters |
|----------|------------------|----------------|
| 🔐 **DM Allowlist** | Set `TELEGRAM_ALLOWED_USER_ID` | Prevents strangers from using your AI |
| 🎫 **Gateway Token** | Auto-generated, use for Control UI | Protects web management interface |
| 🌐 **IP Restrictions** | Set `ALLOWED_IP_RANGES` | Limits network attack surface |
| 🔒 **Secrets in Azure** | Keys stored as secrets, not env vars | Never exposed in logs or source |
| 👤 **Managed Identity** | Enabled by default | No ACR passwords in config |
| 📝 **Audit Logs** | Log Analytics workspace | Track all API calls and access |
| 🚨 **Alerts** | Set `ALERT_EMAIL_ADDRESS` | Immediate notification of issues |
| 🔄 **Key Rotation** | `az containerapp secret set` | Mitigate compromised credentials |

### What NOT to Do

| ❌ Don't | ✅ Do Instead |
|---------|---------------|
| Put API keys in Dockerfile | Use Container App secrets |
| Use `dm.policy: "open"` | Use `dm.policy: "allowlist"` |
| Disable gateway token auth | Always require token for Control UI |
| Skip TELEGRAM_ALLOWED_USER_ID | Always configure the allowlist |
| Leave IP restrictions empty for production | Set ALLOWED_IP_RANGES |
| Ignore alerts | Configure email notifications |

### Security Comparison: ACA vs Other Platforms

| Feature | Azure Container Apps | VPS (Hetzner/DO) | Home Server |
|---------|:--------------------:|:----------------:|:-----------:|
| IP Restrictions | ✅ Built-in | ⚠️ Manual iptables | ⚠️ Manual |
| Automatic TLS | ✅ Free certs | ❌ Manual | ❌ Manual |
| Secrets Management | ✅ Native | ❌ .env files | ❌ .env files |
| Security Alerts | ✅ Azure Monitor | ❌ Self-built | ❌ None |
| Container Isolation | ✅ Hyper-V | ⚠️ Shared kernel | ❌ None |
| Compliance | ✅ SOC2/ISO/HIPAA | ❌ None | ❌ None |

## Estimated Costs

| Resource | What It Does | Monthly Cost |
|----------|--------------|:------------:|
| Container Apps (1 CPU, 2GB RAM, always-on) | Runs MoltBot 24/7 | ~$30-50 |
| Container Registry (Basic) | Stores the image | ~$5 |
| Storage Account | Persists data | ~$1-2 |
| Log Analytics (1GB ingestion) | Stores logs | ~$2-5 |
| **Total** | | **~$40-60/month** |

**Cost Optimization:**
- Scale to 0 replicas when not in use (note: breaks Telegram connection)
- Use a smaller/cheaper model via Azure AI Foundry
- Monitor usage in Azure Portal

## Clean Up

```bash
# Delete everything
azd down --purge
```

This removes all Azure resources. Your data in Azure Storage will be deleted.

## Key Learnings from This Deployment

During the development of this sample, we discovered several important details:

1. **MoltBot requires config file, not just env vars** - The gateway reads from `~/.MoltBot/MoltBot.json`, so we need an entrypoint script to generate it from environment variables.

2. **Config schema matters** - Use `agents.defaults` and `agents.list[].identity`, not the legacy `agent` and `identity` format.

3. **MoltBot ignores OPENAI_BASE_URL** — Even with `OPENAI_BASE_URL` set to your Azure endpoint, MoltBot sends requests to `api.openai.com`, resulting in `401 Incorrect API key`. Our entrypoint script detects Azure endpoints (by matching `cognitiveservices` or `openai.azure` in the URL) and overrides the provider config in the generated JSON — injecting the correct `baseUrl` and `api-key` authentication header.

4. **Model names must match Azure AI Foundry deployments** - Use the **exact** Azure AI Foundry deployment name (case-sensitive).

5. **Telegram requires allowlist** - Bot is online but ignores messages unless your user ID is in `TELEGRAM_ALLOWED_USER_ID`.

6. **Secrets need restart** - After updating Container App secrets, you must restart the revision for changes to take effect.

## Resources

| Resource | Link |
|----------|------|
| 📖 MoltBot Docs | [docs.molt.bot](https://docs.molt.bot) |
| 💻 MoltBot GitHub | [github.com/MoltBot/MoltBot](https://github.com/MoltBot/MoltBot) |
| 💬 MoltBot Community | [discord.gg/molt](https://discord.gg/molt) |
| ☁️ Azure Container Apps | [Documentation](https://learn.microsoft.com/azure/container-apps) |
| 🧠 Azure AI Foundry | [ai.azure.com](https://ai.azure.com) |
| 📦 Sample Repository | [GitHub](https://github.com/BandaruDheeraj/moltbot-azure-container-apps) |

---

> 🦞 Built with MoltBot. Questions? Check [docs.molt.bot](https://docs.molt.bot)
