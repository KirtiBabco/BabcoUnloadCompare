#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
ZIP_URL="https://raw.githubusercontent.com/KirtiBabco/BabcoUnloadCompare/deployment-artifacts/webapp-publish.zip"
ZIP_PATH="/tmp/babco-unloadcompare-webapp.zip"
LIVE_URL="https://${WEBAPP_NAME}.azurewebsites.net/"

az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Clearing stale source-control metadata"
az webapp deployment source delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --change-reference HEAD >/dev/null 2>&1 || true

# Best-effort normalization for App Service SCM configuration. Older source-control
# metadata can make Kudu pass the branch name (main) as ChangeSetId during ZIP deploy.
az webapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --set siteConfig.scmType=None >/dev/null 2>&1 || true

az webapp config appsettings set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false >/dev/null

echo "==> Downloading compiled GitHub Actions package"
curl -fL "$ZIP_URL" -o "$ZIP_PATH"

echo "==> Deploying compiled package to App Service using Kudu HEAD reference"
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --src-path "$ZIP_PATH" \
  --type zip \
  --clean true \
  --restart true \
  --change-reference HEAD \
  --track-status true \
  --timeout 600000

rm -f "$ZIP_PATH"

echo "==> Waiting for application response"
HTTP_CODE="000"
for attempt in $(seq 1 30); do
  HTTP_CODE="$(curl -k -sS -o /tmp/babco-live.html -w '%{http_code}' --max-time 20 "$LIVE_URL" || true)"
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    break
  fi
  echo "Attempt ${attempt}/30: HTTP ${HTTP_CODE}"
  sleep 10
done

printf '\nLIVE_URL=%s\nHTTP_CODE=%s\n' "$LIVE_URL" "$HTTP_CODE"
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
  echo "Deployment completed but the site is not healthy yet." >&2
  exit 4
fi

echo "BABCO UNLOAD COMPARE DEPLOYMENT SUCCESSFUL"
