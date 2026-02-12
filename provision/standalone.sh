#!/usr/bin/env bash
set -euo pipefail

echo "=== Standalone MariaDB provisioning started ==="

export DEBIAN_FRONTEND=noninteractive

# Install MariaDB
apt-get install -y mariadb-server mariadb-client

# Configure MariaDB to bind to the private IP and disable password policy
cat >/etc/mysql/mariadb.conf.d/99-custom.cnf <<EOF
[mysqld]
bind-address = ${NODE_IP}
server-id = ${SERVER_ID}
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

# Create admin user with full privileges
mariadb -u root <<EOSQL
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'mariadb';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOSQL

# Verification
echo "=== Verifying standalone MariaDB ==="
mariadb -uadmin -pmariadb -h "${NODE_IP}" -e "SELECT VERSION();"
echo "=== Standalone provisioning completed ==="
