#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
ZIP_URL="https://raw.githubusercontent.com/KirtiBabco/BabcoUnloadCompare/deployment-artifacts/webapp-publish.zip"
ZIP_PATH="/tmp/babco-unloadcompare-webapp.zip"
SCM_URL="https://${WEBAPP_NAME}.scm.azurewebsites.net"
LIVE_URL="https://${WEBAPP_NAME}.azurewebsites.net/"

az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Clearing legacy source-control configuration"
az webapp deployment source delete --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" >/dev/null 2>&1 || true
az webapp update --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --set siteConfig.scmType=None >/dev/null 2>&1 || true
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false >/dev/null

echo "==> Downloading compiled GitHub Actions package"
curl -fL --retry 3 --retry-delay 2 "$ZIP_URL" -o "$ZIP_PATH"

echo "==> Getting Microsoft Entra token for Kudu"
TOKEN="$(az account get-access-token --query accessToken -o tsv)"
[ -n "$TOKEN" ] || { echo "Unable to obtain Azure access token." >&2; exit 2; }

echo "==> Publishing compiled ZIP directly through Kudu publish API"
PUBLISH_BODY="/tmp/babco-kudu-publish-response.txt"
HTTP_STATUS="$(curl -sS -o "$PUBLISH_BODY" -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/zip" \
  -T "$ZIP_PATH" \
  "${SCM_URL}/api/publish?type=zip&clean=true&restart=true")"

if [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; then
  echo "Kudu publish failed with HTTP ${HTTP_STATUS}." >&2
  cat "$PUBLISH_BODY" >&2 || true
  exit 3
fi

echo "Kudu publish accepted with HTTP ${HTTP_STATUS}."
rm -f "$ZIP_PATH"

# The publish API can finish asynchronously. Restart and health-check until the app responds.
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" >/dev/null

echo "==> Waiting for application response"
HTTP_CODE="000"
for attempt in $(seq 1 36); do
  HTTP_CODE="$(curl -k -sS -o /tmp/babco-live.html -w '%{http_code}' --max-time 20 "$LIVE_URL" || true)"
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    break
  fi
  echo "Attempt ${attempt}/36: HTTP ${HTTP_CODE}"
  sleep 10
done

printf '\nLIVE_URL=%s\nHTTP_CODE=%s\n' "$LIVE_URL" "$HTTP_CODE"
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
  echo "Package was published, but the application is not healthy yet." >&2
  echo "Kudu deployment status:" >&2
  curl -sS -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/deployments/latest" >&2 || true
  exit 4
fi

echo "BABCO UNLOAD COMPARE DEPLOYMENT SUCCESSFUL"
