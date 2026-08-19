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
REPO_URL="https://github.com/KirtiBabco/BabcoUnloadCompare"
REPO_BRANCH="main"
AUTH_APP_DISPLAY_NAME="BabcoUnloadCompare-Web-Auth"

log() { printf '\n==> %s\n' "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

require az
require curl
require openssl

log "Using Azure subscription"
az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID="$(az account show --query tenantId -o tsv)"
CURRENT_SUB="$(az account show --query id -o tsv)"
[ "$CURRENT_SUB" = "$SUBSCRIPTION_ID" ] || { echo "Wrong subscription selected" >&2; exit 1; }

log "Checking resource group and App Service plan"
az group show -n "$RESOURCE_GROUP" >/dev/null
PLAN_TIER="$(az appservice plan show -g "$RESOURCE_GROUP" -n "$APP_SERVICE_PLAN" --query sku.tier -o tsv)"
echo "Plan: $APP_SERVICE_PLAN ($PLAN_TIER)"
case "${PLAN_TIER,,}" in
  free|shared)
    echo "App Service plan tier '$PLAN_TIER' is not suitable for this deployment." >&2
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

log "Creating or reusing Azure SQL with an automatically generated admin secret"
SQL_ADMIN_PASSWORD="Aa1_$(openssl rand -hex 24)"
if ! az sql server show -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" >/dev/null 2>&1; then
  az sql server create -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" -l "$LOCATION" \
    -u "$SQL_ADMIN_USER" -p "$SQL_ADMIN_PASSWORD" \
    --minimal-tls-version 1.2 --enable-public-network true >/dev/null
else
  az sql server update -g "$RESOURCE_GROUP" -n "$SQL_SERVER_NAME" \
    --admin-password "$SQL_ADMIN_PASSWORD" \
    --minimal-tls-version 1.2 --enable-public-network true >/dev/null
fi

log "Creating or reusing Azure SQL database"
if ! az sql db show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE_NAME" >/dev/null 2>&1; then
  az sql db create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$SQL_DATABASE_NAME" \
    --edition GeneralPurpose --family Gen5 --capacity 1 --compute-model Serverless \
    --auto-pause-delay 60 --min-capacity 0.5 --max-size 32GB >/dev/null
fi

log "Restricting Azure SQL firewall to all possible App Service outbound IPs"
OUTBOUND_IPS="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query possibleOutboundIpAddresses -o tsv)"
IFS=',' read -r -a IP_ARRAY <<< "$OUTBOUND_IPS"
idx=1
for ip in "${IP_ARRAY[@]}"; do
  ip="$(echo "$ip" | xargs)"
  [ -n "$ip" ] || continue
  RULE="AppServiceOutbound${idx}"
  if az sql server firewall-rule show -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$RULE" >/dev/null 2>&1; then
    az sql server firewall-rule update -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$RULE" \
      --start-ip-address "$ip" --end-ip-address "$ip" >/dev/null
  else
    az sql server firewall-rule create -g "$RESOURCE_GROUP" -s "$SQL_SERVER_NAME" -n "$RULE" \
      --start-ip-address "$ip" --end-ip-address "$ip" >/dev/null
  fi
  idx=$((idx+1))
done

DB_CS="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DATABASE_NAME};Persist Security Info=False;User ID=${SQL_ADMIN_USER};Password=${SQL_ADMIN_PASSWORD};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

log "Configuring App Service database and build settings"
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings \
  UnloadCompareConnectionString="$DB_CS" \
  BabcoSupportConnectionString="$DB_CS" \
  UnloadCompare.UploadRoot="~/App_Data/Uploads/UnloadCompare" \
  UnloadCompare.MaxUploadMB="15" \
  SCM_DO_BUILD_DURING_DEPLOYMENT="true" \
  PROJECT="BabcoUnloadCompare.Web.csproj" >/dev/null
unset DB_CS SQL_ADMIN_PASSWORD

log "Connecting the public GitHub repository to Azure App Service Build Service"
az webapp deployment source delete -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null 2>&1 || true
az webapp deployment source config -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --repo-url "$REPO_URL" \
  --branch "$REPO_BRANCH" \
  --repository-type externalgit \
  --manual-integration >/dev/null

log "Synchronizing GitHub source and building ASP.NET WebForms in Kudu"
az webapp deployment source sync -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME"
az webapp restart -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null

LIVE_URL="https://${WEBAPP_NAME}.azurewebsites.net/"
log "Waiting for the website to start"
HTTP_CODE="000"
for attempt in $(seq 1 30); do
  HTTP_CODE="$(curl -k -L -sS -o /tmp/babco-unloadcompare-health.html -w '%{http_code}' --max-time 20 "$LIVE_URL" || true)"
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    break
  fi
  echo "Attempt ${attempt}/30: HTTP ${HTTP_CODE}; waiting 10 seconds..."
  sleep 10
done

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
  echo "Website deployment finished but health check returned HTTP ${HTTP_CODE}." >&2
  echo "Recent deployment information:" >&2
  az webapp log deployment show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" 2>/dev/null | tail -80 || true
  exit 4
fi

echo "Website responded with HTTP ${HTTP_CODE}."

log "Configuring Microsoft Entra sign-in (best effort; site remains deployed if tenant policy blocks app registration)"
AUTH_STATUS="not-configured"
set +e
AUTH_CLIENT_ID="$(az ad app list --display-name "$AUTH_APP_DISPLAY_NAME" --query '[0].appId' -o tsv 2>/dev/null)"
if [ -z "$AUTH_CLIENT_ID" ]; then
  AUTH_CLIENT_ID="$(az ad app create \
    --display-name "$AUTH_APP_DISPLAY_NAME" \
    --sign-in-audience AzureADMyOrg \
    --web-redirect-uris "https://${WEBAPP_NAME}.azurewebsites.net/.auth/login/aad/callback" \
    --query appId -o tsv 2>/dev/null)"
fi
if [ -n "$AUTH_CLIENT_ID" ]; then
  AUTH_SECRET="$(az ad app credential reset --id "$AUTH_CLIENT_ID" --append --display-name AppServiceAuth --years 1 --query password -o tsv 2>/dev/null)"
  if [ -n "$AUTH_SECRET" ]; then
    az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings \
      MICROSOFT_PROVIDER_AUTHENTICATION_SECRET="$AUTH_SECRET" >/dev/null 2>&1
    az webapp auth microsoft update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
      --client-id "$AUTH_CLIENT_ID" \
      --client-secret-setting-name MICROSOFT_PROVIDER_AUTHENTICATION_SECRET \
      --tenant-id "$TENANT_ID" --yes >/dev/null 2>&1
    az webapp auth update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
      --enabled true \
      --unauthenticated-client-action RedirectToLoginPage \
      --enable-token-store true \
      --require-https true \
      --set globalValidation.requireAuthentication=true >/dev/null 2>&1
    if [ $? -eq 0 ]; then AUTH_STATUS="enabled"; else AUTH_STATUS="tenant-permission-blocked"; fi
  fi
  unset AUTH_SECRET
fi
set -e

printf '\n============================================================\n'
printf 'BABCO UNLOAD COMPARE FIRST LIVE DEPLOYMENT COMPLETE\n'
printf '============================================================\n'
printf 'WEBAPP_NAME=%s\n' "$WEBAPP_NAME"
printf 'LIVE_URL=%s\n' "$LIVE_URL"
printf 'SQL_SERVER=%s.database.windows.net\n' "$SQL_SERVER_NAME"
printf 'SQL_DATABASE=%s\n' "$SQL_DATABASE_NAME"
printf 'AUTH_STATUS=%s\n' "$AUTH_STATUS"
printf 'SOURCE=%s (%s)\n' "$REPO_URL" "$REPO_BRANCH"
printf '\nApplication DB is live. BabcoSupportConnectionString is temporarily pointed to the same Azure SQL DB so the application can boot. The next infrastructure task is the private/on-prem Babco support database Hybrid Connection.\n'
