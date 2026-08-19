#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="0e27b0b7-22b9-4e96-8faa-897ca9f09e9c"
RESOURCE_GROUP="rg-babco-rnd-sandbox"
LOCATION="centralindia"
APP_SERVICE_PLAN="plan-resolvedesk-kirti20260810"
WEBAPP_NAME="app-babco-unloadcompare-0e27b0b7-260818"
RELAY_NAMESPACE="relay-babco-unloadcompare-0e27b0b7"
HYBRID_CONNECTION_NAME="hc-babco-sql"

log() { printf '\n==> %s\n' "$*"; }
command -v az >/dev/null 2>&1 || { echo "Azure CLI (az) is required." >&2; exit 1; }

az account set --subscription "$SUBSCRIPTION_ID"

HOST="${1:-}"
PORT="${2:-}"
DATABASE_NAME="${3:-Babco}"

if [ -z "$HOST" ]; then
  read -r -p "Babco SQL hostname (DNS name, not IP): " HOST
fi
if [ -z "$PORT" ]; then
  read -r -p "Babco SQL fixed TCP port: " PORT
fi
[ -n "$HOST" ] || { echo "Hostname is required" >&2; exit 2; }
[[ "$PORT" =~ ^[0-9]+$ ]] || { echo "Port must be numeric" >&2; exit 2; }

PLAN_TIER="$(az appservice plan show -g "$RESOURCE_GROUP" -n "$APP_SERVICE_PLAN" --query sku.tier -o tsv)"
case "${PLAN_TIER,,}" in
  free|shared) echo "Hybrid Connections require Basic, Standard, Premium, or Isolated App Service plan." >&2; exit 3 ;;
esac

log "Creating or reusing Azure Relay namespace"
if ! az relay namespace show -g "$RESOURCE_GROUP" -n "$RELAY_NAMESPACE" >/dev/null 2>&1; then
  az relay namespace create -g "$RESOURCE_GROUP" -n "$RELAY_NAMESPACE" -l "$LOCATION" >/dev/null
fi

log "Creating or updating Hybrid Connection endpoint ${HOST}:${PORT}"
USER_METADATA="[{\"key\":\"endpoint\",\"value\":\"${HOST}:${PORT}\"}]"
if az relay hyco show -g "$RESOURCE_GROUP" --namespace-name "$RELAY_NAMESPACE" -n "$HYBRID_CONNECTION_NAME" >/dev/null 2>&1; then
  az relay hyco update -g "$RESOURCE_GROUP" --namespace-name "$RELAY_NAMESPACE" -n "$HYBRID_CONNECTION_NAME" \
    --requires-client-authorization true --user-metadata "$USER_METADATA" >/dev/null
else
  az relay hyco create -g "$RESOURCE_GROUP" --namespace-name "$RELAY_NAMESPACE" -n "$HYBRID_CONNECTION_NAME" \
    --requires-client-authorization true --user-metadata "$USER_METADATA" >/dev/null
fi

log "Attaching Hybrid Connection to Web App"
if ! az webapp hybrid-connection list -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
  --query "[?name=='${HYBRID_CONNECTION_NAME}'] | [0].name" -o tsv | grep -q .; then
  az webapp hybrid-connection add -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" \
    --namespace "$RELAY_NAMESPACE" --hybrid-connection "$HYBRID_CONNECTION_NAME" >/dev/null
fi

log "Configuring BabcoSupportConnectionString"
read -r -p "Babco SQL login (use a least-privilege read-only account): " SQL_USER
read -r -s -p "Babco SQL password: " SQL_PASSWORD
echo
read -r -p "SQL encryption enabled? [Y/n]: " SQL_ENCRYPT
SQL_ENCRYPT="${SQL_ENCRYPT:-Y}"
if [[ "$SQL_ENCRYPT" =~ ^[Yy]$ ]]; then
  read -r -p "Trust SQL Server certificate? [y/N]: " TRUST_CERT
  TRUST_CERT="${TRUST_CERT:-N}"
  if [[ "$TRUST_CERT" =~ ^[Yy]$ ]]; then
    TLS_PART="Encrypt=True;TrustServerCertificate=True;"
  else
    TLS_PART="Encrypt=True;TrustServerCertificate=False;"
  fi
else
  TLS_PART="Encrypt=False;"
fi

SUPPORT_CS="Server=${HOST},${PORT};Initial Catalog=${DATABASE_NAME};User ID=${SQL_USER};Password=${SQL_PASSWORD};${TLS_PART}Connect Timeout=30;"
az webapp config appsettings set -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --settings \
  BabcoSupportConnectionString="$SUPPORT_CS" >/dev/null
unset SQL_PASSWORD SUPPORT_CS
az webapp restart -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME"

printf '\n============================================================\n'
printf 'AZURE HYBRID CONNECTION CONFIGURED\n'
printf '============================================================\n'
printf 'Web App: %s\n' "$WEBAPP_NAME"
printf 'Relay Namespace: %s\n' "$RELAY_NAMESPACE"
printf 'Hybrid Connection: %s\n' "$HYBRID_CONNECTION_NAME"
printf 'Endpoint: %s:%s\n' "$HOST" "$PORT"
printf '\nIMPORTANT LOCAL-SERVER STEP:\n'
printf 'Install the current Microsoft Hybrid Connection Manager on a Windows/Linux machine that can resolve and reach %s:%s.\n' "$HOST" "$PORT"
printf 'In HCM, sign in to Azure, select subscription %s, and add hybrid connection %s.\n' "$SUBSCRIPTION_ID" "$HYBRID_CONNECTION_NAME"
printf 'The App Service Hybrid Connection status must become Connected before live Babco PO reads can work.\n'