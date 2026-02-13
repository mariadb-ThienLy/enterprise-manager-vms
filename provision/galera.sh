#!/usr/bin/env bash
set -euo pipefail

echo "=== Galera MariaDB provisioning started ==="
echo "Node IP: ${NODE_IP}"
echo "Node Index: ${NODE_INDEX}"
echo "Galera IPs: ${GALERA_IPS}"

export DEBIAN_FRONTEND=noninteractive

# Remove community galera-4 if present (conflicts with galera-enterprise-4)
apt-get remove -y galera-4 || true

# Install MariaDB with Galera Enterprise
apt-get install -y mariadb-server mariadb-client galera-enterprise-4

# Build the wsrep_cluster_address from GALERA_IPS
# Format: gcomm://ip1,ip2,ip3
CLUSTER_ADDR="gcomm://${GALERA_IPS}"

# Configure Galera
cat >/etc/mysql/mariadb.conf.d/99-custom.cnf <<EOF
[mariadb]
server-id = ${SERVER_ID}
gtid_domain_id = 0
log_bin = mariadb-bin
binlog_format = ROW
log_slave_updates = ON
bind-address = ${NODE_IP}
default_storage_engine = InnoDB
innodb_file_per_table = ON
innodb_autoinc_lock_mode = 2
simple_password_check = 0

[galera]
wsrep_on = ON
wsrep_provider = /usr/lib/libgalera_smm.so
wsrep_cluster_name = galera_cluster
wsrep_cluster_address = ${CLUSTER_ADDR}
wsrep_node_address = ${NODE_IP}
wsrep_node_incoming_address = ${NODE_IP}
wsrep_sst_receive_address = ${NODE_IP}
wsrep_node_name = ${NODE_NAME}
wsrep_sst_method = rsync
wsrep_sst_auth = admin:mariadb
wsrep_gtid_mode = ON
wsrep_gtid_domain_id = 0
wsrep_slave_threads = 1
wsrep_certify_nonPK = 1
wsrep_convert_LOCK_to_trx = 0
wsrep_retry_autocommit = 1
wsrep_auto_increment_control = 1
EOF

# Check if MariaDB is running and if cluster is healthy
CLUSTER_HEALTHY=false
if systemctl is-active --quiet mariadb 2>/dev/null; then
  # Try to check cluster status
  if mariadb-admin ping --silent 2>/dev/null; then
    CLUSTER_SIZE=$(mariadb -uadmin -pmariadb -e "SHOW STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null | grep wsrep_cluster_size | awk '{print $2}')
    if [ -n "$CLUSTER_SIZE" ] && [ "$CLUSTER_SIZE" -gt 0 ]; then
      echo "Cluster is healthy with $CLUSTER_SIZE nodes. Skipping provisioning."
      CLUSTER_HEALTHY=true
    fi
  fi
fi

# If cluster is healthy, exit early
if [ "$CLUSTER_HEALTHY" = "true" ]; then
  echo "=== Galera cluster already provisioned and healthy ==="
  systemctl enable mariadb
  exit 0
fi

# Cluster is not healthy, proceed with recovery/provisioning
echo "Cluster is not healthy or not initialized. Proceeding with recovery..."

# Stop MariaDB before bootstrapping/joining
systemctl stop mariadb || true
sleep 2

# Clean up stale cluster state files to force recovery
# This is necessary after a halt/up cycle when the cluster was not cleanly shut down
if [ -f /var/lib/mysql/grastate.dat ]; then
  # Check if safe_to_bootstrap is set (indicates this node can bootstrap)
  if grep -q "safe_to_bootstrap: 1" /var/lib/mysql/grastate.dat; then
    echo "Node can safely bootstrap the cluster (grastate.dat indicates safe_to_bootstrap: 1)"
  else
    echo "Resetting grastate.dat to allow bootstrap recovery..."
    rm -f /var/lib/mysql/grastate.dat
  fi
fi

# Determine if this is the first Galera node by checking if NODE_IP matches the first IP in GALERA_IPS
FIRST_GALERA_IP=$(echo "${GALERA_IPS}" | cut -d',' -f1)
IS_FIRST_NODE=false
if [ "${NODE_IP}" = "${FIRST_GALERA_IP}" ]; then
  IS_FIRST_NODE=true
fi

if [ "${IS_FIRST_NODE}" = "true" ]; then
  # First node: bootstrap the cluster
  echo "Bootstrapping Galera cluster (first node)..."
  
  # Initialize system tables if they don't exist
  if [ ! -d /var/lib/mysql/mysql ]; then
    echo "Initializing MariaDB system tables..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db 2>&1 | grep -v "WARNING\|deprecated" || true
  fi
  
  # Use mysqld_safe with wsrep-new-cluster flag to bootstrap
  # This is more reliable than systemctl for Galera bootstrap
  # The --wsrep-new-cluster flag forces this node to bootstrap even if grastate.dat exists
  mysqld_safe --wsrep-new-cluster &
  MYSQLD_PID=$!
  
  # Wait for bootstrap to complete (up to 120 seconds, increased from 90 to handle slow systems)
  echo "Waiting for first node to bootstrap..."
  BOOTSTRAP_SUCCESS=false
  for i in $(seq 1 120); do
    if mariadb-admin ping --silent 2>/dev/null; then
      echo "First node is ready."
      BOOTSTRAP_SUCCESS=true
      break
    fi
    if [ $((i % 10)) -eq 0 ]; then
      echo "Still waiting for first node... ($i/120 seconds)"
    fi
    if [ "$i" -eq 120 ]; then
      echo "WARNING: First node did not respond after 120 seconds"
    fi
    sleep 1
  done

  # Create admin user
  echo "Creating admin user..."
  mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'mariadb';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOSQL

  # Create MaxScale users
  echo "Creating MaxScale users..."
  mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'mariadb';
GRANT REPLICATION CLIENT, REPLICATION SLAVE, SUPER, RELOAD, PROCESS, SHOW DATABASES, EVENT ON *.* TO 'admin'@'%';
FLUSH PRIVILEGES;
EOSQL
  
  echo "First node bootstrap completed."

else
  # Non-first node: wait for the first node to be ready, then join
  FIRST_IP=$(echo "${GALERA_IPS}" | cut -d',' -f1)
  echo "Waiting for first Galera node at ${FIRST_IP}..."
  for i in $(seq 1 120); do
    if mariadb-admin ping -h "${FIRST_IP}" -u admin -pmariadb --silent 2>/dev/null; then
      echo "First node is reachable."
      break
    fi
    if [ "$i" -eq 120 ]; then
      echo "ERROR: First Galera node not reachable after 120 seconds"
      exit 1
    fi
    sleep 2
  done

  # Start MariaDB (it will join the cluster via wsrep_cluster_address)
  systemctl start mariadb

  # Wait for MariaDB to be ready
  for i in $(seq 1 60); do
    if mariadb-admin ping --silent 2>/dev/null; then
      break
    fi
    sleep 2
  done
fi

systemctl enable mariadb

# Verification
echo "=== Verifying Galera node ==="
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SELECT VERSION();"
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW STATUS LIKE 'wsrep_ready';"
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW STATUS LIKE 'wsrep_local_state_comment';"

echo "=== Galera provisioning completed ==="
