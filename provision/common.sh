#!/usr/bin/env bash
set -euo pipefail

echo "=== Common provisioning started ==="
echo "Role: ${ROLE}"
echo "Node IP: ${NODE_IP}"
echo "Node Name: ${NODE_NAME}"
echo "Topology: ${TOPOLOGY}"

export DEBIAN_FRONTEND=noninteractive

# Fix DNS resolution: disable DNSSEC which can cause SERVFAIL on some networks
sed -i 's/^#\?DNSSEC=.*$/DNSSEC=no/' /etc/systemd/resolved.conf
systemctl restart systemd-resolved
sleep 2

# Basic system prep
apt-get update -y
apt-get install -y curl gnupg lsb-release software-properties-common apt-transport-https

# Set up MariaDB Enterprise Server repository using mariadb_es_repo_setup
echo "Setting up MariaDB Enterprise Server repository..."

# Verify token is available
if [ -z "${ENTERPRISE_TOKEN}" ]; then
  echo "ERROR: ENTERPRISE_TOKEN not set"
  exit 1
fi

# Set up MariaDB Enterprise Server repository
# Create sources file directly with token embedded in URLs (no Signed-By since GPG key will be in system keyring)
echo "Creating MariaDB Enterprise sources file..."
mkdir -p /etc/apt/sources.list.d/

cat > /etc/apt/sources.list.d/mariadb.sources <<EOF
Types: deb
Architectures: amd64 arm64
URIs: https://dlm.mariadb.com/repo/${ENTERPRISE_TOKEN}/mariadb-enterprise-server/11.8/deb
Suites: jammy
Components: main

Types: deb
Architectures: amd64 arm64
URIs: https://dlm.mariadb.com/repo/${ENTERPRISE_TOKEN}/mariadb-enterprise-server/11.8/deb
Suites: jammy
Components: main/debug

Types: deb
Architectures: amd64 arm64
URIs: https://dlm.mariadb.com/repo/${ENTERPRISE_TOKEN}/enterprise-tools/latest/deb
Suites: jammy
Components: main
EOF

# Import GPG key for repository authentication
echo "Importing MariaDB Enterprise GPG key..."
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CE1A3DD5E3C94F49 2>&1 | grep -i "imported\|key"

echo "MariaDB Enterprise sources file created successfully"
cat /etc/apt/sources.list.d/mariadb.sources

# Update package cache
echo "Running apt-get update..."
apt-get update -y

echo "=== Common provisioning completed ==="
