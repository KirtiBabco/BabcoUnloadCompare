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

echo "==> Getting Microsoft Entra token for Kudu"
TOKEN="$(az account get-access-token --query accessToken -o tsv)"
[ -n "$TOKEN" ] || { echo "Unable to obtain Azure access token." >&2; exit 2; }

echo "==> Checking compiled WebForms files in wwwroot"
VFS_BODY="/tmp/babco-wwwroot.json"
VFS_CODE="$(curl -sS -o "$VFS_BODY" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/")"
NEED_DEPLOY=false
if [ "$VFS_CODE" != "200" ]; then
  NEED_DEPLOY=true
elif ! grep -q 'UnloadCompare.aspx' "$VFS_BODY" || ! grep -q 'Web.config' "$VFS_BODY" || ! grep -q 'BabcoUnloadCompare.Web.dll' "$VFS_BODY"; then
  # DLL may be inside bin and not in the root listing; check bin before deciding.
  BIN_CODE="$(curl -sS -o /tmp/babco-bin.json -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "${SCM_URL}/api/vfs/site/wwwroot/bin/")"
  if [ "$BIN_CODE" != "200" ] || ! grep -q 'BabcoUnloadCompare.Web.dll' /tmp/babco-bin.json; then
    NEED_DEPLOY=true
  fi
fi

if [ "$NEED_DEPLOY" = "true" ]; then
  echo "==> Deploying already-compiled WebForms package"
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
  echo "Compiled WebForms files already exist."
fi

echo "==> Installing root redirect without changing Azure default-document configuration"
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
if [ "$REDIRECT_CODE" -lt 200 ] || [ "$REDIRECT_CODE" -ge 300 ]; then
  echo "Unable to write hostingstart.html redirect." >&2
  cat /tmp/babco-vfs-write.txt >&2 || true
  exit 6
fi

az webapp start -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" >/dev/null
sleep 8

echo "==> Testing direct WebForms endpoint first"
APP_BODY="/tmp/babco-app.html"
APP_CODE="$(curl -k -sS -o "$APP_BODY" -w '%{http_code}' --max-time 30 "$LIVE_URL/UnloadCompare.aspx" || true)"
echo "UnloadCompare.aspx HTTP=$APP_CODE"

ROOT_BODY="/tmp/babco-root.html"
ROOT_CODE="$(curl -k -sS -o "$ROOT_BODY" -w '%{http_code}' --max-time 30 "$LIVE_URL/" || true)"
echo "Root HTTP=$ROOT_CODE"

healthy() { [ "$1" = "200" ] || [ "$1" = "301" ] || [ "$1" = "302" ]; }
if healthy "$APP_CODE"; then
  echo "BABCO UNLOAD COMPARE APPLICATION IS LIVE"
  echo "APP_URL=${LIVE_URL}/UnloadCompare.aspx"
  echo "ROOT_URL=${LIVE_URL}/"
  exit 0
fi

echo "==> Direct ASPX endpoint is not healthy"
echo "App Service state=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query state -o tsv 2>/dev/null || true)"
echo "UnloadCompare.aspx response:"
sed -n '1,80p' "$APP_BODY" 2>/dev/null || true
if [ "$APP_CODE" = "500" ]; then
  echo "RESULT=APPLICATION_500"
elif [ "$APP_CODE" = "403" ]; then
  echo "RESULT=DIRECT_ASPX_403"
else
  echo "RESULT=DIRECT_ASPX_HTTP_${APP_CODE}"
fi
exit 4
