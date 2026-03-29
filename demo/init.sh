#!/bin/bash
#
# Demo Bootstrap Script for Dataverse
# This script customizes and secures your Dataverse installation for demo/production use

# Set unblock key for admin API access (CHANGE THIS!)
UNBLOCK_KEY="${UNBLOCK_KEY:-unblockme}"

# Wait for Dataverse to be responsive
echo "Waiting for Dataverse to be responsive..."
timeout=300
counter=0
until curl -s http://dataverse:8080/api/info/version > /dev/null 2>&1; do
  sleep 5
  counter=$((counter + 5))
  if [ $counter -ge $timeout ]; then
    echo "ERROR: Dataverse did not become responsive within $timeout seconds"
    exit 1
  fi
done
echo "Dataverse is responsive!"

# Setup script without insecure flag
echo "Running secure setup..."
/opt/dv/dvinstall/setup-all.sh

# Set the unblock key for admin API access
echo "Setting unblock key for admin API..."
curl -X PUT -d "$UNBLOCK_KEY" "http://dataverse:8080/api/admin/settings/:BlockedApiKey"

# Configure some basic settings
echo "Configuring basic settings..."

# Set site name
curl -X PUT -d "Dataverse Demo" "http://dataverse:8080/api/admin/settings/:InstallationName?unblock-key=$UNBLOCK_KEY"

# Set footer copyright
curl -X PUT -d "© 2026 Your Organization" "http://dataverse:8080/api/admin/settings/:FooterCopyright?unblock-key=$UNBLOCK_KEY"

# Set site URL
curl -X PUT -d "${DATAVERSE_URL:-http://localhost:8080}" "http://dataverse:8080/api/admin/settings/:SiteUrl?unblock-key=$UNBLOCK_KEY"

# Enable file PIDs (optional)
# curl -X PUT -d "true" "http://dataverse:8080/api/admin/settings/:FilePIDsEnabled?unblock-key=$UNBLOCK_KEY"

# Configure upload size limits (in bytes, default 2GB)
# curl -X PUT -d "2147483648" "http://dataverse:8080/api/admin/settings/:MaxFileUploadSizeInBytes?unblock-key=$UNBLOCK_KEY"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║  Dataverse Demo/Production Setup Complete!                   ║"
echo "║                                                               ║"
echo "║  Access your Dataverse instance at:                          ║"
echo "║  http://localhost:8080                                        ║"
echo "║                                                               ║"
echo "║  Default credentials:                                         ║"
echo "║  Username: dataverseAdmin                                     ║"
echo "║  Password: admin1                                             ║"
echo "║                                                               ║"
echo "║  Admin API Unblock Key: $UNBLOCK_KEY"
echo "║  (Use this key when calling admin API endpoints)             ║"
echo "║                                                               ║"
echo "║  MailDev (Email Web UI):                                      ║"
echo "║  http://localhost:1080                                        ║"
echo "║                                                               ║"
echo "║  Payara Admin Console:                                        ║"
echo "║  http://localhost:4949                                        ║"
echo "║  Username: admin                                              ║"
echo "║  Password: admin                                              ║"
echo "║                                                               ║"
echo "║  SECURITY NOTICE:                                             ║"
echo "║  - Change the unblock key for production use!                 ║"
echo "║  - Change database password in .env file                      ║"
echo "║  - Change default admin password after first login            ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Example API calls that require unblock key:
# curl -X PUT -d "New Value" "http://localhost:8080/api/admin/settings/:SettingName?unblock-key=$UNBLOCK_KEY"

exit 0
