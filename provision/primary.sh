#!/usr/bin/env bash
set -euo pipefail

echo "=== Primary MariaDB provisioning started ==="

export DEBIAN_FRONTEND=noninteractive

# Install MariaDB
apt-get install -y mariadb-server mariadb-client

# Configure MariaDB: bind to private IP, enable binary logging, disable password policy
cat >/etc/mysql/mariadb.conf.d/99-custom.cnf <<EOF
[mysqld]
bind-address = ${NODE_IP}
server-id = ${SERVER_ID}
log_bin = mariadb-bin
binlog_format = ROW
log_slave_updates = ON
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

# Create admin user with all privileges (used by both admin and MaxScale)
mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'mariadb';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOSQL

# Create dedicated replication user
mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
EOSQL

# Verification
echo "=== Verifying primary MariaDB ==="
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SELECT VERSION();"
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW VARIABLES LIKE 'log_bin';"
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SHOW MASTER STATUS;"
echo "=== Primary provisioning completed ==="
