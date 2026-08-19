#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
EXPECTED_SOURCE="3eb360df036edcd12a0b11a24ec38346d545db26"
BUILD_INFO_URL="https://raw.githubusercontent.com/KirtiBabco/BabcoUnloadCompare/deployment-artifacts/build.txt"
ZIP_URL="https://raw.githubusercontent.com/KirtiBabco/BabcoUnloadCompare/deployment-artifacts/webapp-publish.zip"
ZIP_PATH="/tmp/babco-unloadcompare-webapp.zip"
SCM_URL="https://${WEBAPP_NAME}.scm.azurewebsites.net"
LIVE_URL="https://${WEBAPP_NAME}.azurewebsites.net"

az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Waiting for GitHub Actions to publish the fail-safe startup build"
BUILD_SOURCE=""
for attempt in $(seq 1 45); do
  BUILD_SOURCE="$(curl -fsSL "${BUILD_INFO_URL}?t=${attempt}" 2>/dev/null | sed -n 's/^Source commit: //p' | tr -d '\r' || true)"
  if [ "$BUILD_SOURCE" = "$EXPECTED_SOURCE" ]; then
    echo "Compiled package ready: $BUILD_SOURCE"
    break
  fi
  echo "Build not ready yet (${attempt}/45). Current artifact: ${BUILD_SOURCE:-unknown}"
  sleep 8
done
if [ "$BUILD_SOURCE" != "$EXPECTED_SOURCE" ]; then
  echo "GitHub Actions package for $EXPECTED_SOURCE is not ready yet. Re-run this script in a minute." >&2
  exit 11
fi

echo "==> Removing only the stale conflicting App Setting (secret Connection String is untouched)"
az webapp config appsettings delete -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --setting-names BabcoSupportConnectionString >/dev/null 2>&1 || true

echo "==> Verifying Azure secret Connection String metadata"
CS_META="$(az webapp config connection-string list -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --query "[?name=='BabcoSupportConnectionString'].{Name:name,Type:type}" -o tsv 2>/dev/null || true)"
if [ -z "$CS_META" ]; then
  echo "WARNING: BabcoSupportConnectionString is not present under App Service Environment variables > Connection strings." >&2
else
  echo "$CS_META"
fi

echo "==> Starting Windows App Service with safe runtime settings"
az webapp start -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
az webapp config set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --always-on true \
  --net-framework-version v4.0 \
  --min-tls-version 1.2 \
  --http20-enabled true \
  --remote-debugging-enabled false >/dev/null
az webapp update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --set publicNetworkAccess=Enabled >/dev/null 2>&1 || true
az webapp config access-restriction set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --default-action Allow >/dev/null 2>&1 || true

echo "==> Enabling diagnostics"
az webapp log config -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --application-logging filesystem \
  --level information \
  --web-server-logging filesystem \
  --detailed-error-messages true \
  --failed-request-tracing true >/dev/null 2>&1 || true

echo "==> Disabling run-from-package so site/wwwroot is writable"
az webapp config appsettings delete -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --setting-names WEBSITE_RUN_FROM_PACKAGE WEBSITE_RUN_FROM_ZIP >/dev/null 2>&1 || true
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false >/dev/null

sleep 5

echo "==> Getting Microsoft Entra token for Kudu"
TOKEN="$(az account get-access-token --query accessToken -o tsv)"
[ -n "$TOKEN" ] || { echo "Unable to obtain Azure access token." >&2; exit 2; }

echo "==> Downloading compiled GitHub Actions package"
curl -fL --retry 3 --retry-delay 2 "${ZIP_URL}?source=${EXPECTED_SOURCE}" -o "$ZIP_PATH"

echo "==> Expanding ZIP directly into Kudu site/wwwroot"
ZIP_BODY="/tmp/babco-kudu-zip-response.txt"
ZIP_CODE="$(curl -sS -o "$ZIP_BODY" -w '%{http_code}' \
  -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @"$ZIP_PATH" \
  "${SCM_URL}/api/zip/site/wwwroot/")"
echo "Kudu direct wwwroot ZIP HTTP=$ZIP_CODE"
rm -f "$ZIP_PATH"
if [ "$ZIP_CODE" -lt 200 ] || [ "$ZIP_CODE" -ge 300 ]; then
  echo "Direct wwwroot expansion failed." >&2
  cat "$ZIP_BODY" >&2 || true
  exit 3
fi

echo "==> Verifying required files"
ROOT_JSON="/tmp/babco-wwwroot.json"
BIN_JSON="/tmp/babco-bin.json"
ROOT_VFS="$(curl -sS -o "$ROOT_JSON" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/")"
BIN_VFS="$(curl -sS -o "$BIN_JSON" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/bin/")"
if [ "$ROOT_VFS" != "200" ] || ! grep -q 'UnloadCompare.aspx' "$ROOT_JSON" || ! grep -q 'Web.config' "$ROOT_JSON"; then
  echo "VERIFY_FAILED: required ASPX/Web.config files are not in wwwroot." >&2
  exit 7
fi
if [ "$BIN_VFS" != "200" ] || ! grep -q 'BabcoUnloadCompare.Web.dll' "$BIN_JSON"; then
  echo "VERIFY_FAILED: BabcoUnloadCompare.Web.dll is not in wwwroot/bin." >&2
  exit 8
fi

echo "Verified compiled WebForms files."

echo "==> Restarting App Service"
az webapp restart -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null

APP_BODY="/tmp/babco-app.html"
APP_CODE="000"
for attempt in $(seq 1 30); do
  APP_CODE="$(curl -k -sS -o "$APP_BODY" -w '%{http_code}' --max-time 30 "$LIVE_URL/UnloadCompare.aspx" || true)"
  echo "Health ${attempt}/30: HTTP $APP_CODE"
  if [ "$APP_CODE" = "200" ] || [ "$APP_CODE" = "301" ] || [ "$APP_CODE" = "302" ]; then
    echo "BABCO UNLOAD COMPARE APPLICATION IS LIVE"
    echo "APP_URL=${LIVE_URL}/UnloadCompare.aspx"
    exit 0
  fi
  sleep 6
done

echo "==> App is still unhealthy"
echo "App Service state=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv 2>/dev/null || true)"
echo "HTTP_CODE=$APP_CODE"
if [ "$APP_CODE" = "503" ]; then
  echo "RESULT=APP_SERVICE_503"
elif [ "$APP_CODE" = "500" ]; then
  echo "RESULT=APPLICATION_500"
elif [ "$APP_CODE" = "403" ]; then
  echo "RESULT=DIRECT_ASPX_403"
elif [ "$APP_CODE" = "404" ]; then
  echo "RESULT=PHYSICAL_FILES_EXIST_BUT_IIS_404"
else
  echo "RESULT=DIRECT_ASPX_HTTP_${APP_CODE}"
fi
exit 4
