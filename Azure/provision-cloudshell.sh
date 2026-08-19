#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
LOCATION="centralindia"
APP_SERVICE_PLAN="plan-resolvedesk-kirti20260810"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
SQL_SERVER_NAME="sql-babco-unloadcompare-0e27b0b7-260818"
SQL_DATABASE_NAME="BabcoUnloadCompareDb"
SQL_ADMIN_USER="babcoUnloadAdmin"
REPO_FULL_NAME="KirtiBabco/BabcoUnloadCompare"
DEPLOY_APP_DISPLAY_NAME="BabcoUnloadCompare-GitHub-Deploy"
AUTH_APP_DISPLAY_NAME="BabcoUnloadCompare-Web-Auth"

log() { printf '\n==> %s\n' "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

read_sql_password_twice() {
  while true; do
    IFS= read -r -s -p "SQL admin password: " SQL_ADMIN_PASSWORD </dev/tty
    printf '\n' >/dev/tty
    IFS= read -r -s -p "Confirm SQL admin password: " SQL_ADMIN_PASSWORD_2 </dev/tty
    printf '\n' >/dev/tty
    if [ -n "$SQL_ADMIN_PASSWORD" ] && [ "$SQL_ADMIN_PASSWORD" = "$SQL_ADMIN_PASSWORD_2" ]; then
      return 0
    fi
    echo "Passwords do not match or are empty. Please try again." >/dev/tty
  done
}

read_sql_password_once() {
  while true; do
    IFS= read -r -s -p "SQL admin password: " SQL_ADMIN_PASSWORD </dev/tty
    printf '\n' >/dev/tty
    [ -n "$SQL_ADMIN_PASSWORD" ] && return 0
    echo "Password cannot be empty. Please try again." >/dev/tty
  done
}

require az

log "Using Azure subscription"
az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID="$(az account show --query tenantId -o tsv)"
CURRENT_SUB="$(az account show --query id -o tsv)"
[ "$CURRENT_SUB" = "$SUBSCRIPTION_ID" ] || { echo "Wrong subscription selected" >&2; exit 1; }

log "Checking resource group and App Service plan"
az group show -n "$RESOURCE_GROUP" >/dev/null
PLAN_ID="$(az appservice plan show -g "$RESOURCE_GROUP" -n "$APP_SERVICE_PLAN" --query id -o tsv)"
PLAN_TIER="$(az appservice plan show -g "$RESOURCE_GROUP" -n "$APP_SERVICE_PLAN" --query sku.tier -o tsv)"
echo "Plan: $APP_SERVICE_PLAN ($PLAN_TIER)"

case "${PLAN_TIER,,}" in
  free|shared)
    echo "App Service plan tier '$PLAN_TIER' does not support the intended production/hybrid setup. Upgrade the plan before continuing." >&2
    exit 2
    ;;
esac

log "Creating or reusing Windows Web App"
if ! az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null 2>&1; then
  az webapp create -g "$RESOURCE_GROUP" -p "$APP_SERVICE_PLAN" -n "$WEBAPP_NAME" >/dev/null
fi
az webapp config set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --net-framework-version v4.0 \
  --always-on true \
  --http20-enabled true \
  --ftps-state Disabled \
  --min-tls-version 1.2 >/dev/null
az webapp update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --https-only true >/dev/null

log "Creating or reusing Azure SQL logical server"
if ! az sql server show -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" >/dev/null 2>&1; then
  echo "Azure SQL server does not exist yet. Enter a NEW strong SQL admin password. It will not be printed."
  read_sql_password_twice
  az sql server create -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" -l "$LOCATION" \
    -u "$SQL_ADMIN_USER" -p "$SQL_ADMIN_PASSWORD" --minimal-tls-version 1.2 --enable-public-network true >/dev/null
else
  echo "Azure SQL server already exists. Enter its SQL admin password only to configure the app connection string."
  read_sql_password_once
fi

log "Creating or reusing Azure SQL database"
if ! az sql db show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE_NAME" >/dev/null 2>&1; then
  az sql db create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE_NAME" \
    --edition GeneralPurpose --family Gen5 --capacity 1 --compute-model Serverless \
    --auto-pause-delay 60 --min-capacity 0.5 --max-size 32GB >/dev/null
fi

log "Restricting Azure SQL firewall to this Web App outbound IP set"
OUTBOUND_IPS="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query outboundIpAddresses -o tsv)"
IFS=',' read -r -a IP_ARRAY <<< "$OUTBOUND_IPS"
idx=1
for ip in "${IP_ARRAY[@]}"; do
  ip="$(echo "$ip" | xargs)"
  [ -n "$ip" ] || continue
  az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" \
    -n "AppServiceOutbound${idx}" --start-ip-address "$ip" --end-ip-address "$ip" >/dev/null 2>&1 || \
  az sql server firewall-rule update -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" \
    -n "AppServiceOutbound${idx}" --start-ip-address "$ip" --end-ip-address "$ip" >/dev/null
  idx=$((idx+1))
done

DB_CS="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DATABASE_NAME};Persist Security Info=False;User ID=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
unset SQL_ADMIN_PASSWORD SQL_ADMIN_PASSWORD_2 || true

log "Configuring application settings for first live boot"
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings \
  UnloadCompareConnectionString="$DB_CS" \
  BabcoSupportConnectionString="$DB_CS" \
  UnloadCompare.UploadRoot="~/App_Data/Uploads/UnloadCompare" \
  UnloadCompare.MaxUploadMB="15" >/dev/null
unset DB_CS

log "Creating or reusing Microsoft Entra app registration for website sign-in"
AUTH_CLIENT_ID="$(az ad app list --display-name "$AUTH_APP_DISPLAY_NAME" --query '[0].appId' -o tsv)"
if [ -z "$AUTH_CLIENT_ID" ]; then
  AUTH_CLIENT_ID="$(az ad app create \
    --display-name "$AUTH_APP_DISPLAY_NAME" \
    --sign-in-audience AzureADMyOrg \
    --web-redirect-uris "https://${WEBAPP_NAME}.azurewebsites.net/.auth/login/aad/callback" \
    --query appId -o tsv)"
fi
AUTH_SECRET="$(az ad app credential reset --id "$AUTH_CLIENT_ID" --append --display-name AppServiceAuth --years 1 --query password -o tsv)"
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings \
  MICROSOFT_PROVIDER_AUTHENTICATION_SECRET="$AUTH_SECRET" >/dev/null
unset AUTH_SECRET

az webapp auth microsoft update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --client-id "$AUTH_CLIENT_ID" \
  --client-secret-setting-name MICROSOFT_PROVIDER_AUTHENTICATION_SECRET \
  --tenant-id "$TENANT_ID" --yes >/dev/null
az webapp auth update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --enabled true \
  --unauthenticated-client-action RedirectToLoginPage \
  --enable-token-store true \
  --require-https true \
  --set globalValidation.requireAuthentication=true >/dev/null

log "Creating or reusing GitHub OIDC deployment identity"
DEPLOY_CLIENT_ID="$(az ad app list --display-name "$DEPLOY_APP_DISPLAY_NAME" --query '[0].appId' -o tsv)"
if [ -z "$DEPLOY_CLIENT_ID" ]; then
  DEPLOY_CLIENT_ID="$(az ad app create --display-name "$DEPLOY_APP_DISPLAY_NAME" --query appId -o tsv)"
fi
DEPLOY_APP_OBJECT_ID="$(az ad app show --id "$DEPLOY_CLIENT_ID" --query id -o tsv)"
SP_OBJECT_ID="$(az ad sp show --id "$DEPLOY_CLIENT_ID" --query id -o tsv 2>/dev/null || true)"
if [ -z "$SP_OBJECT_ID" ]; then
  SP_OBJECT_ID="$(az ad sp create --id "$DEPLOY_CLIENT_ID" --query id -o tsv)"
fi
WEBAPP_ID="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query id -o tsv)"
if ! az role assignment list --assignee-object-id "$SP_OBJECT_ID" --scope "$WEBAPP_ID" --query "[?roleDefinitionName=='Website Contributor'] | [0].id" -o tsv | grep -q .; then
  az role assignment create --role "Website Contributor" --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal --scope "$WEBAPP_ID" >/dev/null
fi

FED_NAME="github-main-production"
FED_JSON="$(mktemp)"
cat > "$FED_JSON" <<JSON
{
  "name": "$FED_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${REPO_FULL_NAME}:environment:production",
  "description": "BabcoUnloadCompare GitHub Actions production deployment",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
if ! az ad app federated-credential list --id "$DEPLOY_APP_OBJECT_ID" --query "[?name=='${FED_NAME}'] | [0].name" -o tsv | grep -q .; then
  az ad app federated-credential create --id "$DEPLOY_APP_OBJECT_ID" --parameters "$FED_JSON" >/dev/null
fi
rm -f "$FED_JSON"

log "Restarting Web App"
az webapp restart -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME"

printf '\n============================================================\n'
printf 'CORE AZURE PROVISIONING COMPLETE\n'
printf '============================================================\n'
printf 'WEBAPP_NAME=%s\n' "$WEBAPP_NAME"
printf 'LIVE_URL=https://%s.azurewebsites.net/\n' "$WEBAPP_NAME"
printf 'SQL_SERVER=%s.database.windows.net\n' "$SQL_SERVER_NAME"
printf 'SQL_DATABASE=%s\n' "$SQL_DATABASE_NAME"
printf 'AZURE_CLIENT_ID=%s\n' "$DEPLOY_CLIENT_ID"
printf 'AZURE_TENANT_ID=%s\n' "$TENANT_ID"
printf 'AZURE_SUBSCRIPTION_ID=%s\n' "$SUBSCRIPTION_ID"
printf 'AUTH_CLIENT_ID=%s\n' "$AUTH_CLIENT_ID"
printf '\nNEXT: add the four GitHub Actions values above, enable AZURE_DEPLOY_ENABLED=true, then configure the live BabcoSupport database/Hybrid Connection.\n'