#!/bin/bash
# =============================================================================
# Solr Collection Initializer for Dataverse
# Ensures collection1 exists with the proper Dataverse schema.
# Runs as an init container before Dataverse starts.
# =============================================================================
set -euo pipefail

SOLR_HOST="${SOLR_HOST:-solr}"
SOLR_PORT="${SOLR_PORT:-8983}"
SOLR_URL="http://${SOLR_HOST}:${SOLR_PORT}"
CORE_NAME="collection1"
SCHEMA_DIR="/opt/dataverse-solr-conf"
MAX_WAIT="${SOLR_INIT_TIMEOUT:-120}"

echo "=== Dataverse Solr Initializer ==="
echo "Solr URL: ${SOLR_URL}"
echo "Core:     ${CORE_NAME}"

# --- Wait for Solr to be ready ---
echo "Waiting for Solr to become ready (max ${MAX_WAIT}s)..."
elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
    if curl -sf "${SOLR_URL}/solr/admin/cores?action=STATUS" >/dev/null 2>&1; then
        echo "Solr is ready (${elapsed}s)."
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

if [ $elapsed -ge $MAX_WAIT ]; then
    echo "ERROR: Solr did not become ready within ${MAX_WAIT}s."
    exit 1
fi

# --- Check if collection1 already exists and is healthy ---
CORE_STATUS=$(curl -sf "${SOLR_URL}/solr/admin/cores?action=STATUS&core=${CORE_NAME}" 2>/dev/null || echo '{}')
INIT_FAILURES=$(echo "$CORE_STATUS" | grep -c '"initFailures":{}' || true)
HAS_INDEX=$(echo "$CORE_STATUS" | grep -c '"indexDir"' || true)

if [ "$HAS_INDEX" -gt 0 ] && [ "$INIT_FAILURES" -gt 0 ]; then
    echo "collection1 exists and is healthy. Nothing to do."
    exit 0
fi

echo "collection1 needs initialization..."

# --- Unload broken core if it exists with init failures ---
INIT_FAIL_CHECK=$(echo "$CORE_STATUS" | grep -c 'initFailures":{[^}]' || true)
if [ "$INIT_FAIL_CHECK" -gt 0 ]; then
    echo "Unloading broken collection1..."
    curl -sf "${SOLR_URL}/solr/admin/cores?action=UNLOAD&core=${CORE_NAME}&deleteDataDir=true&deleteInstanceDir=true&deleteIndex=true" >/dev/null 2>&1 || true
    sleep 2
fi

# --- Create core with default config first ---
echo "Creating ${CORE_NAME} with default Solr config..."
curl -sf "${SOLR_URL}/solr/admin/cores?action=CREATE&name=${CORE_NAME}&configSet=_default" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    # Try alternative creation method
    SOLR_BIN=$(find / -name "solr" -path "*/bin/*" -type f 2>/dev/null | head -1)
    if [ -n "$SOLR_BIN" ]; then
        echo "Trying alternative core creation..."
        # Use Solr API directly
        curl -sf "${SOLR_URL}/solr/admin/cores?action=CREATE&name=${CORE_NAME}&instanceDir=${CORE_NAME}&configSet=_default" >/dev/null 2>&1 || true
    fi
fi

# --- Replace schema.xml with Dataverse schema ---
echo "Installing Dataverse schema..."

# Upload schema.xml via Solr Config API (managed schema mode) 
# First, switch to classic schema mode by uploading schema.xml directly
# We need to copy files into the Solr data directory
# Find the core's conf directory
CORE_CONF_CANDIDATES=(
    "/var/solr/data/${CORE_NAME}/conf"
    "/opt/solr/server/solr/${CORE_NAME}/conf"
)

CORE_CONF=""
for candidate in "${CORE_CONF_CANDIDATES[@]}"; do
    if [ -d "$candidate" ]; then
        CORE_CONF="$candidate"
        break
    fi
done

if [ -z "$CORE_CONF" ]; then
    echo "ERROR: Could not find core conf directory."
    echo "Searched: ${CORE_CONF_CANDIDATES[*]}"
    exit 1
fi

echo "Core config directory: ${CORE_CONF}"

# Copy Dataverse schema (but keep the default solrconfig.xml which is compatible)
cp "${SCHEMA_DIR}/schema.xml" "${CORE_CONF}/schema.xml"

# Copy lang directory for stopword files referenced by schema
if [ -d "${SCHEMA_DIR}/lang" ]; then
    cp -r "${SCHEMA_DIR}/lang" "${CORE_CONF}/lang"
fi

# Remove managed-schema if it exists (conflicts with classic schema.xml)
rm -f "${CORE_CONF}/managed-schema.xml" "${CORE_CONF}/managed-schema"

echo "Reloading ${CORE_NAME}..."
RELOAD_RESULT=$(curl -sf "${SOLR_URL}/solr/admin/cores?action=RELOAD&core=${CORE_NAME}" 2>&1)
RELOAD_STATUS=$(echo "$RELOAD_RESULT" | grep -c '"status":0' || true)

if [ "$RELOAD_STATUS" -gt 0 ]; then
    echo "=== collection1 initialized successfully ==="
    exit 0
else
    echo "WARNING: Reload returned unexpected result: ${RELOAD_RESULT}"
    echo "Attempting verification..."
    
    # Verify the core is functional
    VERIFY=$(curl -sf "${SOLR_URL}/solr/${CORE_NAME}/admin/ping" 2>&1 || echo "FAIL")
    if echo "$VERIFY" | grep -q '"status":"OK"'; then
        echo "=== collection1 is functional (verified via ping) ==="
        exit 0
    else
        echo "ERROR: collection1 could not be initialized."
        exit 1
    fi
fi
