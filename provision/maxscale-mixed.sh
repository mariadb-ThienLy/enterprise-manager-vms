#!/usr/bin/env bash
set -euo pipefail

echo "=== MaxScale provisioning started (mixed topology) ==="
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

# Separate primary/replica from galera servers
PRIMARY_REPLICA_SERVERS=""
GALERA_SERVERS=""
for name in "${NAMES[@]}"; do
  if [[ "$name" == *"primary"* ]] || [[ "$name" == *"replica"* ]]; then
    if [ -n "${PRIMARY_REPLICA_SERVERS}" ]; then
      PRIMARY_REPLICA_SERVERS="${PRIMARY_REPLICA_SERVERS}, ${name}"
    else
      PRIMARY_REPLICA_SERVERS="${name}"
    fi
  elif [[ "$name" == *"galera"* ]]; then
    if [ -n "${GALERA_SERVERS}" ]; then
      GALERA_SERVERS="${GALERA_SERVERS}, ${name}"
    else
      GALERA_SERVERS="${name}"
    fi
  fi
done

# Generate MaxScale configuration with config sync
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
config_sync_cluster=Galera-Monitor
config_sync_user=admin
config_sync_password=mariadb
config_sync_interval=5s

${SERVER_DEFS}

[MariaDB-Monitor]
type=monitor
module=mariadbmon
servers=${PRIMARY_REPLICA_SERVERS}
user=admin
password=mariadb
monitor_interval=2000ms
auto_failover=true
auto_rejoin=true

[Galera-Monitor]
type=monitor
module=galeramon
servers=${GALERA_SERVERS}
user=admin
password=mariadb
monitor_interval=2000ms

[Read-Write-Service]
type=service
router=readwritesplit
servers=${PRIMARY_REPLICA_SERVERS}
user=admin
password=mariadb

[Read-Write-Listener]
type=listener
service=Read-Write-Service
protocol=MariaDBClient
address=0.0.0.0
port=4006

[Galera-Service]
type=service
router=readconnroute
servers=${GALERA_SERVERS}
user=admin
password=mariadb

[Galera-Listener]
type=listener
service=Galera-Service
protocol=MariaDBClient
address=0.0.0.0
port=4007
EOF

# Wait for backend servers to be ready before starting MaxScale
echo "Waiting for backend servers to be ready (up to 120 seconds)..."
BACKENDS_READY=false
for i in $(seq 1 60); do
  READY=true
  for ip in ${IPS[@]}; do
    if ! mariadb-admin ping -h "$ip" --silent 2>/dev/null; then
      READY=false
      break
    fi
  done
  if [ "$READY" = "true" ]; then
    echo "All backend servers are ready"
    BACKENDS_READY=true
    break
  fi
  echo "Waiting for backend servers... ($i/60)"
  sleep 2
done

if [ "$BACKENDS_READY" = "false" ]; then
  echo "WARNING: Not all backend servers are ready, but proceeding with MaxScale startup"
  echo "MaxScale monitors will discover backends as they come online"
fi

# Start MaxScale (backends will be discovered by monitor)
echo "Starting MaxScale service..."
systemctl restart maxscale || {
  echo "ERROR: Failed to start MaxScale service"
  systemctl status maxscale
  exit 1
}
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
