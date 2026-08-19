#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
ZIP_URL="https://raw.githubusercontent.com/KirtiBabco/BabcoUnloadCompare/deployment-artifacts/webapp-publish.zip"
ZIP_PATH="/tmp/babco-unloadcompare-webapp.zip"
SCM_URL="https://${WEBAPP_NAME}.scm.azurewebsites.net"
LIVE_URL="https://${WEBAPP_NAME}.azurewebsites.net"
CFG_URI="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${WEBAPP_NAME}/config/web?api-version=2025-03-01"

az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Verifying Windows App Service platform"
RESERVED="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query reserved -o tsv)"
if [ "$RESERVED" = "true" ]; then
  echo "FATAL_PLATFORM: Classic ASP.NET WebForms requires Windows App Service." >&2
  exit 10
fi

echo "==> Starting App Service and applying safe runtime settings"
az webapp start -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
az webapp config set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --always-on true \
  --net-framework-version v4.0 \
  --min-tls-version 1.2 \
  --http20-enabled true >/dev/null
az webapp update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --set publicNetworkAccess=Enabled >/dev/null 2>&1 || true

# Keep the site reachable while we validate the WebForms runtime. Entra auth is
# re-enabled later after the application itself is healthy.
az webapp config access-restriction set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --default-action Allow >/dev/null 2>&1 || true
az webapp auth update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --enabled false >/dev/null 2>&1 || true

echo "==> Repairing IIS default document and root virtual application"
az rest --method patch --uri "$CFG_URI" --body '{"properties":{"managedPipelineMode":"Integrated","netFrameworkVersion":"v4.0","defaultDocuments":["Default.aspx","UnloadCompare.aspx","Default.htm","Default.html","index.html","hostingstart.html"],"virtualApplications":[{"virtualPath":"/","physicalPath":"site\\wwwroot","preloadEnabled":true}]}}' >/dev/null

echo "==> Getting Microsoft Entra token for Kudu"
TOKEN="$(az account get-access-token --query accessToken -o tsv)"
[ -n "$TOKEN" ] || { echo "Unable to obtain Azure access token." >&2; exit 2; }

echo "==> Checking site/wwwroot contents"
VFS_BODY="/tmp/babco-wwwroot.json"
VFS_CODE="$(curl -sS -o "$VFS_BODY" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/")"
NEED_DEPLOY=false
if [ "$VFS_CODE" != "200" ]; then
  NEED_DEPLOY=true
elif ! grep -q 'Default.aspx' "$VFS_BODY" || ! grep -q 'Web.config' "$VFS_BODY" || ! grep -q 'UnloadCompare.aspx' "$VFS_BODY"; then
  NEED_DEPLOY=true
fi

if [ "$NEED_DEPLOY" = "true" ]; then
  echo "==> Deploying compiled WebForms package"
  curl -fL --retry 3 --retry-delay 2 "$ZIP_URL" -o "$ZIP_PATH"
  PUBLISH_BODY="/tmp/babco-kudu-publish-response.txt"
  HTTP_STATUS="$(curl -sS -o "$PUBLISH_BODY" -w '%{http_code}' \
    -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/zip" \
    -T "$ZIP_PATH" \
    "${SCM_URL}/api/publish?type=zip&clean=true&restart=false")"
  rm -f "$ZIP_PATH"
  if [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; then
    echo "Kudu publish failed with HTTP ${HTTP_STATUS}." >&2
    cat "$PUBLISH_BODY" >&2 || true
    exit 3
  fi
  echo "Kudu publish accepted with HTTP ${HTTP_STATUS}."
else
  echo "Required WebForms files already exist at site/wwwroot."
fi

az webapp start -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
sleep 10
STATE="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv)"
echo "App Service state=$STATE"
[ "$STATE" = "Running" ] || { echo "App Service is not Running." >&2; exit 5; }

echo "==> Testing root and ASPX endpoints"
probe() {
  local url="$1"
  curl -k -sS -o /tmp/babco-probe.html -w '%{http_code}' --max-time 30 "$url" || true
}
ROOT_CODE="$(probe "$LIVE_URL/")"
DEFAULT_CODE="$(probe "$LIVE_URL/Default.aspx")"
APP_CODE="$(probe "$LIVE_URL/UnloadCompare.aspx")"
echo "HTTP root=$ROOT_CODE default.aspx=$DEFAULT_CODE unloadcompare.aspx=$APP_CODE"

healthy() { [ "$1" = "200" ] || [ "$1" = "301" ] || [ "$1" = "302" ]; }
if healthy "$ROOT_CODE" || healthy "$DEFAULT_CODE" || healthy "$APP_CODE"; then
  echo "BABCO UNLOAD COMPARE SITE IS RESPONDING"
  echo "LIVE_URL=${LIVE_URL}/"
  exit 0
fi

echo "==> Site still unhealthy; collecting exact diagnostics"
echo "State=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv 2>/dev/null || true)"
echo "DefaultDocuments=$(az webapp config show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultDocuments -o json 2>/dev/null || true)"
echo "VirtualApplications=$(az webapp config show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query virtualApplications -o json 2>/dev/null || true)"
echo "AccessRestrictions=$(az webapp config access-restriction show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" -o json 2>/dev/null | head -80 || true)"
echo "Auth=$(az webapp auth show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" -o json 2>/dev/null | head -80 || true)"
echo "KuduVFS=$(cat "$VFS_BODY" 2>/dev/null | head -40 || true)"

if [ "$ROOT_CODE" = "403" ] || [ "$DEFAULT_CODE" = "403" ] || [ "$APP_CODE" = "403" ]; then
  echo "RESULT=HTTP_403_REMAINS"
elif [ "$ROOT_CODE" = "500" ] || [ "$DEFAULT_CODE" = "500" ] || [ "$APP_CODE" = "500" ]; then
  echo "RESULT=APPLICATION_500"
else
  echo "RESULT=UNHEALTHY_HTTP"
fi
exit 4
