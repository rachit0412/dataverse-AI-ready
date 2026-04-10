#!/bin/bash
# Dataverse Demo Mode Initialization Script
# This script configures Dataverse with demo mode security (unblock key required for admin APIs)

set -euo pipefail

# ============================================================================
# SECURITY: UNBLOCK KEY
# ============================================================================
# Generate a secure random unblock key for admin API protection
# IMPORTANT: Change this to a strong random value before deploying
# Generate new key: openssl rand -hex 32

UNBLOCK_KEY="changeme-replace-with-random-key"

# Store unblock key for reference (not committed to git)
echo "$UNBLOCK_KEY" > /tmp/unblock-key.txt
echo "Unblock key stored in /tmp/unblock-key.txt"

# ============================================================================
# WAIT FOR DATAVERSE TO BE READY
# ============================================================================
echo "Waiting for Dataverse to be ready..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -sf http://dataverse:8080/api/info/version > /dev/null 2>&1; then
        echo "Dataverse is ready!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts: Waiting for Dataverse..."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: Dataverse failed to become ready"
    exit 1
fi

# ============================================================================
# CONFIGURE DEMO MODE
# ============================================================================
echo "Configuring Dataverse demo mode..."

# Set unblock key for admin API protection
curl -X PUT "http://dataverse:8080/api/admin/settings/:BlockedApiPolicy" \
     -d "unblock-key" \
     || echo "Warning: Could not set blocked API policy"

curl -X PUT "http://dataverse:8080/api/admin/settings/:BlockedApiKey" \
     -d "$UNBLOCK_KEY" \
     || echo "Warning: Could not set unblock key"

# ============================================================================
# BASIC CONFIGURATION
# ============================================================================
echo "Applying basic configuration..."

# Set installation name
curl -X PUT "http://dataverse:8080/api/admin/settings/:InstallationName?unblock-key=$UNBLOCK_KEY" \
     -d "Dataverse Demo" \
     || echo "Warning: Could not set installation name"

# Set system email
curl -X PUT "http://dataverse:8080/api/admin/settings/:SystemEmail?unblock-key=$UNBLOCK_KEY" \
     -d "dataverse@localhost" \
     || echo "Warning: Could not set system email"

# Set footer copyright
curl -X PUT "http://dataverse:8080/api/admin/settings/:FooterCopyright?unblock-key=$UNBLOCK_KEY" \
     -d "Demo Installation" \
     || echo "Warning: Could not set footer copyright"

# ============================================================================
# SECURITY SETTINGS
# ============================================================================
echo "Applying security settings..."

# Set minimum password length
curl -X PUT "http://dataverse:8080/api/admin/settings/:PVMinLength?unblock-key=$UNBLOCK_KEY" \
     -d "12" \
     || echo "Warning: Could not set password length"

# Require good passwords
curl -X PUT "http://dataverse:8080/api/admin/settings/:PVGoodStrength?unblock-key=$UNBLOCK_KEY" \
     -d "3" \
     || echo "Warning: Could not set password strength"

# ============================================================================
# COMPLETION
# ============================================================================
echo ""
echo "=========================================="
echo "Demo mode configuration complete!"
echo "=========================================="
echo ""
echo "Access Dataverse at: http://localhost:8080"
echo "Default admin: dataverseAdmin / admin1"
echo ""
echo "IMPORTANT: Admin API operations now require unblock key"
echo "Unblock key: $UNBLOCK_KEY"
echo ""
echo "Example API call with unblock key:"
echo "curl -X PUT \"http://localhost:8080/api/admin/settings/:InstallationName?unblock-key=$UNBLOCK_KEY\" -d \"My Dataverse\""
echo ""
echo "=========================================="
