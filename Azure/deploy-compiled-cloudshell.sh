#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
ZIP_URL="https://raw.githubusercontent.com/KirtiBabco/BabcoUnloadCompare/deployment-artifacts/webapp-publish.zip"
ZIP_PATH="/tmp/babco-unloadcompare-webapp.zip"
SCM_URL="https://${WEBAPP_NAME}.scm.azurewebsites.net"
LIVE_URL="https://${WEBAPP_NAME}.azurewebsites.net"

az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Inspecting App Service platform"
STATE="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv)"
RESERVED="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query reserved -o tsv)"
KIND="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query kind -o tsv)"
PLAN_ID="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query serverFarmId -o tsv)"
echo "State=$STATE"
echo "Kind=$KIND"
echo "LinuxReserved=$RESERVED"
echo "Plan=$PLAN_ID"

if [ "$RESERVED" = "true" ]; then
  echo "FATAL_PLATFORM: This Web App is on a Linux App Service plan. Classic ASP.NET WebForms requires Windows App Service." >&2
  exit 10
fi

echo "==> Enforcing Windows ASP.NET/IIS site configuration"
cat > /tmp/babco-site-config.json <<'JSON'
{
  "alwaysOn": true,
  "netFrameworkVersion": "v4.0",
  "managedPipelineMode": "Integrated",
  "defaultDocuments": [
    "Default.aspx",
    "UnloadCompare.aspx",
    "default.aspx",
    "Default.htm",
    "Default.html",
    "index.html",
    "hostingstart.html"
  ],
  "virtualApplications": [
    {
      "virtualPath": "/",
      "physicalPath": "site\\wwwroot",
      "preloadEnabled": true
    }
  ],
  "detailedErrorLoggingEnabled": true,
  "httpLoggingEnabled": true,
  "requestTracingEnabled": true
}
JSON
az webapp config set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --generic-configurations @/tmp/babco-site-config.json >/dev/null
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false >/dev/null

echo "==> Getting Microsoft Entra token for Kudu"
TOKEN="$(az account get-access-token --query accessToken -o tsv)"
[ -n "$TOKEN" ] || { echo "Unable to obtain Azure access token." >&2; exit 2; }

echo "==> Verifying deployed files in site/wwwroot"
VFS_BODY="/tmp/babco-wwwroot.json"
VFS_CODE="$(curl -sS -o "$VFS_BODY" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/")"
echo "Kudu VFS HTTP=$VFS_CODE"
NEED_DEPLOY=false
if [ "$VFS_CODE" != "200" ]; then
  NEED_DEPLOY=true
else
  if ! grep -q 'Default.aspx' "$VFS_BODY" || ! grep -q 'Web.config' "$VFS_BODY" || ! grep -q 'UnloadCompare.aspx' "$VFS_BODY"; then
    NEED_DEPLOY=true
  fi
fi

if [ "$NEED_DEPLOY" = "true" ]; then
  echo "==> Required files are not present at wwwroot; deploying compiled package"
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
  echo "Required files already exist at site/wwwroot. No redeploy needed."
fi

echo "==> Starting App Service"
az webapp start -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
sleep 8
STATE="$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv)"
echo "App Service state=$STATE"
[ "$STATE" = "Running" ] || { echo "App Service is not Running." >&2; exit 5; }

echo "==> Testing live endpoints"
probe() {
  local label="$1"
  local url="$2"
  local body="/tmp/babco-${label}.html"
  local code
  code="$(curl -k -sS -o "$body" -w '%{http_code}' --max-time 30 "$url" || true)"
  printf '%s=%s\n' "$label" "$code"
  printf '%s' "$code"
}

ROOT_CODE="$(probe ROOT "$LIVE_URL/")"
DEFAULT_CODE="$(probe DEFAULT "$LIVE_URL/Default.aspx")"
APP_CODE="$(probe APP "$LIVE_URL/UnloadCompare.aspx")"

# probe prints both label and return value; keep the final line only.
ROOT_CODE="$(printf '%s\n' "$ROOT_CODE" | tail -n 1)"
DEFAULT_CODE="$(printf '%s\n' "$DEFAULT_CODE" | tail -n 1)"
APP_CODE="$(printf '%s\n' "$APP_CODE" | tail -n 1)"

echo "HTTP root=$ROOT_CODE default.aspx=$DEFAULT_CODE unloadcompare.aspx=$APP_CODE"

healthy() { [ "$1" = "200" ] || [ "$1" = "301" ] || [ "$1" = "302" ]; }
if healthy "$ROOT_CODE" || healthy "$DEFAULT_CODE" || healthy "$APP_CODE"; then
  echo "BABCO UNLOAD COMPARE SITE IS RESPONDING"
  echo "LIVE_URL=${LIVE_URL}/"
  exit 0
fi

echo "==> Site is still not healthy; collecting Azure configuration"
echo "Default documents:"
az webapp config show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultDocuments -o json || true
echo "Virtual applications:"
az webapp config show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query virtualApplications -o json || true
echo "Access restriction defaults:"
az webapp config show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query '{mainDefault:ipSecurityRestrictionsDefaultAction,scmDefault:scmIpSecurityRestrictionsDefaultAction}' -o json || true
echo "Authentication configuration:"
az webapp auth show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" -o json 2>/dev/null | head -80 || true

echo "Response body for /Default.aspx:"
sed -n '1,60p' /tmp/babco-DEFAULT.html 2>/dev/null || true

echo "Kudu latest deployment:"
curl -sS -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/deployments/latest" || true

if [ "$ROOT_CODE" = "403" ] || [ "$DEFAULT_CODE" = "403" ] || [ "$APP_CODE" = "403" ]; then
  echo "RESULT=HTTP_403_REMAINS"
elif [ "$ROOT_CODE" = "500" ] || [ "$DEFAULT_CODE" = "500" ] || [ "$APP_CODE" = "500" ]; then
  echo "RESULT=APPLICATION_500"
else
  echo "RESULT=UNHEALTHY_HTTP"
fi
exit 4
