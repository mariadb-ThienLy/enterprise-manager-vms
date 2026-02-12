#!/usr/bin/env bash
set -euo pipefail

echo "=== MaxScale provisioning started ==="
echo "Node IP: ${NODE_IP}"
echo "Topology: ${TOPOLOGY}"
echo "Backend IPs: ${BACKEND_IPS}"
echo "Backend Names: ${BACKEND_NAMES}"

export DEBIAN_FRONTEND=noninteractive

# Verify enterprise token is available (passed by Vagrantfile)
if [ -z "${ENTERPRISE_TOKEN}" ]; then
  echo "ERROR: ENTERPRISE_TOKEN not set"
  exit 1
fi

# Install mariadb-client for connectivity checks
apt-get install -y mariadb-client curl

# Install MaxScale 25.10.1 enterprise from repository
echo "Installing MaxScale 25.10.1 enterprise from repository..."
curl -LsS https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup | bash -s -- --token="${ENTERPRISE_TOKEN}" --mariadb-maxscale-version=25.10.1 --apply
apt-get install -y maxscale

# Install MaxScale module dependencies for GUI and all optional modules
echo "Installing MaxScale module dependencies..."
apt-get install -y libboost-serialization1.74.0 librdkafka++1 libmemcached11

# Verify installation
echo "MaxScale version:"
maxscale --version || true

# Determine topology type for MaxScale config
IFS=',' read -ra IPS <<< "${BACKEND_IPS}"
IFS=',' read -ra NAMES <<< "${BACKEND_NAMES}"

# Build server definitions
SERVER_DEFS=""
SERVER_LIST=""
for i in "${!IPS[@]}"; do
  SERVER_DEFS="${SERVER_DEFS}
[${NAMES[$i]}]
type=server
address=${IPS[$i]}
port=3306
protocol=MariaDBBackend
"
  if [ -n "${SERVER_LIST}" ]; then
    SERVER_LIST="${SERVER_LIST}, ${NAMES[$i]}"
  else
    SERVER_LIST="${NAMES[$i]}"
  fi
done

# Determine monitor and router type based on topology
if [[ "${TOPOLOGY}" == *"galera"* ]]; then
  MONITOR_MODULE="galeramon"
  ROUTER_MODULE="readconnroute"
  ROUTER_OPTIONS="router_options=synced"
else
  MONITOR_MODULE="mariadbmon"
  ROUTER_MODULE="readwritesplit"
  ROUTER_OPTIONS=""
fi

# Generate MaxScale configuration
cat >/etc/maxscale.cnf <<EOF
[maxscale]
threads=auto
admin_host=0.0.0.0
admin_port=8989
admin_secure_gui=false
admin_oidc_url=https://192.168.1.18:8090
admin_oidc_client_id=admin
admin_oidc_client_secret=mariadb
admin_oidc_ssl_insecure=true

${SERVER_DEFS}

[MariaDB-Monitor]
type=monitor
module=${MONITOR_MODULE}
servers=${SERVER_LIST}
user=admin
password=mariadb
monitor_interval=2000ms
EOF

# Add topology-specific monitor options
if [[ "${TOPOLOGY}" == *"galera"* ]]; then
  cat >>/etc/maxscale.cnf <<EOF

[Read-Write-Service]
type=service
router=${ROUTER_MODULE}
servers=${SERVER_LIST}
user=admin
password=mariadb
${ROUTER_OPTIONS}

[Read-Write-Listener]
type=listener
service=Read-Write-Service
protocol=MariaDBClient
address=0.0.0.0
port=4006
EOF
else
  cat >>/etc/maxscale.cnf <<EOF
auto_failover=true
auto_rejoin=true

[Read-Write-Service]
type=service
router=${ROUTER_MODULE}
servers=${SERVER_LIST}
user=admin
password=mariadb

[Read-Write-Listener]
type=listener
service=Read-Write-Service
protocol=MariaDBClient
address=0.0.0.0
port=4006
EOF
fi

# Start MaxScale (backends will be discovered by monitor)
echo "Starting MaxScale service..."
systemctl restart maxscale
systemctl enable maxscale

# Wait for MaxScale to start
sleep 5

# Verification
echo "=== Verifying MaxScale ==="
maxscale --version
systemctl is-active maxscale || echo "MaxScale service status check failed"

# Try to list servers if maxctrl is available
if command -v maxctrl &> /dev/null; then
  echo "MaxScale servers:"
  maxctrl list servers || echo "maxctrl list servers failed - MaxScale may still be starting"
  echo "MaxScale services:"
  maxctrl list services || echo "maxctrl list services failed - MaxScale may still be starting"
fi

echo "=== MaxScale provisioning completed ==="
