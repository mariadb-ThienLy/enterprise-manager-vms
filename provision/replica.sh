#!/usr/bin/env bash
set -euo pipefail

echo "=== Replica MariaDB provisioning started ==="
echo "Primary IP: ${PRIMARY_IP}"

export DEBIAN_FRONTEND=noninteractive

# Install MariaDB
apt-get install -y mariadb-server mariadb-client

# Configure MariaDB: bind to private IP, read-only, disable password policy
cat >/etc/mysql/mariadb.conf.d/99-custom.cnf <<EOF
[mysqld]
bind-address = ${NODE_IP}
server-id = ${SERVER_ID}
log_bin = mariadb-bin
binlog_format = ROW
log_slave_updates = ON
read_only = ON
simple_password_check = 0
EOF

systemctl restart mariadb
systemctl enable mariadb

# Wait for MariaDB to be ready
for i in $(seq 1 30); do
  if mariadb-admin ping --silent 2>/dev/null; then
    break
  fi
  sleep 1
done

# Create admin user (needs SUPER to bypass read_only)
mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'mariadb';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOSQL

# Create MaxScale users on replica too
mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'mariadb';
GRANT REPLICATION CLIENT, REPLICATION SLAVE, SUPER, RELOAD, PROCESS, SHOW DATABASES, EVENT ON *.* TO 'admin'@'%';
FLUSH PRIVILEGES;
EOSQL

# Wait for primary to be reachable
echo "Waiting for primary at ${PRIMARY_IP}..."
for i in $(seq 1 60); do
  if mariadb-admin ping -h "${PRIMARY_IP}" -u repl -prepl_password --silent 2>/dev/null; then
    echo "Primary is reachable."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: Primary not reachable after 60 seconds"
    exit 1
  fi
  sleep 2
done

# Configure replication
mariadb -u root <<EOSQL
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='${PRIMARY_IP}',
  MASTER_USER='repl',
  MASTER_PASSWORD='repl_password',
  MASTER_USE_GTID=slave_pos;
START SLAVE;
EOSQL

# Wait for replication to start
sleep 5

# Verification
echo "=== Verifying replica MariaDB ==="
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SELECT VERSION();"
SLAVE_IO=$(mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running" | awk '{print $2}')
SLAVE_SQL=$(mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running" | head -1 | awk '{print $2}')
echo "Slave_IO_Running: ${SLAVE_IO}"
echo "Slave_SQL_Running: ${SLAVE_SQL}"

if [ "${SLAVE_IO}" != "Yes" ] || [ "${SLAVE_SQL}" != "Yes" ]; then
  echo "ERROR: Replication is not running correctly!"
  mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW SLAVE STATUS\G"
  exit 1
fi

echo "=== Replica provisioning completed ==="
