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

echo "==> Starting Windows App Service"
az webapp start -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
az webapp config set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --always-on true \
  --net-framework-version v4.0 \
  --min-tls-version 1.2 \
  --http20-enabled true >/dev/null
az webapp update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --set publicNetworkAccess=Enabled >/dev/null 2>&1 || true
az webapp config access-restriction set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --default-action Allow >/dev/null 2>&1 || true
az webapp auth update -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --enabled false >/dev/null 2>&1 || true

echo "==> Disabling any run-from-package mode so site/wwwroot is writable"
az webapp config appsettings delete -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --setting-names WEBSITE_RUN_FROM_PACKAGE WEBSITE_RUN_FROM_ZIP >/dev/null 2>&1 || true
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false >/dev/null

sleep 5

echo "==> Getting Microsoft Entra token for Kudu"
TOKEN="$(az account get-access-token --query accessToken -o tsv)"
[ -n "$TOKEN" ] || { echo "Unable to obtain Azure access token." >&2; exit 2; }

echo "==> Downloading already-compiled GitHub Actions package"
curl -fL --retry 3 --retry-delay 2 "$ZIP_URL" -o "$ZIP_PATH"

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

echo "==> Verifying required files physically exist in site/wwwroot"
ROOT_JSON="/tmp/babco-wwwroot.json"
BIN_JSON="/tmp/babco-bin.json"
ROOT_VFS="$(curl -sS -o "$ROOT_JSON" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/")"
BIN_VFS="$(curl -sS -o "$BIN_JSON" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/bin/")"
echo "wwwroot listing HTTP=$ROOT_VFS; bin listing HTTP=$BIN_VFS"

if [ "$ROOT_VFS" != "200" ] || ! grep -q 'UnloadCompare.aspx' "$ROOT_JSON" || ! grep -q 'Web.config' "$ROOT_JSON"; then
  echo "VERIFY_FAILED: UnloadCompare.aspx/Web.config not found in physical wwwroot." >&2
  cat "$ROOT_JSON" >&2 || true
  exit 7
fi
if [ "$BIN_VFS" != "200" ] || ! grep -q 'BabcoUnloadCompare.Web.dll' "$BIN_JSON"; then
  echo "VERIFY_FAILED: BabcoUnloadCompare.Web.dll not found in physical wwwroot/bin." >&2
  cat "$BIN_JSON" >&2 || true
  exit 8
fi

echo "Verified: UnloadCompare.aspx, Web.config, and bin/BabcoUnloadCompare.Web.dll exist."

echo "==> Writing root redirect via Kudu VFS"
cat > /tmp/hostingstart.html <<'HTML'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=/UnloadCompare.aspx">
  <title>Babco Unload Compare</title>
  <script>location.replace('/UnloadCompare.aspx');</script>
</head>
<body><a href="/UnloadCompare.aspx">Open Babco Unload Compare</a></body>
</html>
HTML
REDIRECT_CODE="$(curl -sS -o /tmp/babco-vfs-write.txt -w '%{http_code}' \
  -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "If-Match: *" \
  -H "Content-Type: text/html; charset=utf-8" \
  --data-binary @/tmp/hostingstart.html \
  "${SCM_URL}/api/vfs/site/wwwroot/hostingstart.html")"
echo "hostingstart.html write HTTP=$REDIRECT_CODE"

az webapp restart -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
sleep 12

echo "==> Testing direct WebForms endpoint"
APP_BODY="/tmp/babco-app.html"
APP_CODE="$(curl -k -sS -o "$APP_BODY" -w '%{http_code}' --max-time 45 "$LIVE_URL/UnloadCompare.aspx" || true)"
echo "UnloadCompare.aspx HTTP=$APP_CODE"
ROOT_CODE="$(curl -k -sS -o /tmp/babco-root.html -w '%{http_code}' --max-time 45 "$LIVE_URL/" || true)"
echo "Root HTTP=$ROOT_CODE"

healthy() { [ "$1" = "200" ] || [ "$1" = "301" ] || [ "$1" = "302" ]; }
if healthy "$APP_CODE"; then
  echo "BABCO UNLOAD COMPARE APPLICATION IS LIVE"
  echo "APP_URL=${LIVE_URL}/UnloadCompare.aspx"
  echo "ROOT_URL=${LIVE_URL}/"
  exit 0
fi

echo "==> Direct ASPX endpoint is still not healthy"
echo "App Service state=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv 2>/dev/null || true)"
echo "UnloadCompare.aspx response:"
sed -n '1,100p' "$APP_BODY" 2>/dev/null || true
if [ "$APP_CODE" = "500" ]; then
  echo "RESULT=APPLICATION_500"
elif [ "$APP_CODE" = "403" ]; then
  echo "RESULT=DIRECT_ASPX_403"
elif [ "$APP_CODE" = "404" ]; then
  echo "RESULT=PHYSICAL_FILES_EXIST_BUT_IIS_404"
else
  echo "RESULT=DIRECT_ASPX_HTTP_${APP_CODE}"
fi
exit 4
