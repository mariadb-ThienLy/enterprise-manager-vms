---
name: MariaDB Provisioning
description: Knowledge and procedures for provisioning MariaDB in Vagrant VMs
tags: [mariadb, provisioning, database]
---

# MariaDB Provisioning Skill

## Overview
This skill provides expertise in provisioning MariaDB Enterprise Server in Vagrant-based Ubuntu VMs.

## Key Knowledge

### Installation
- MariaDB Enterprise Server 11.8 LTS
- Install from official MariaDB repositories
- Requires ENTERPRISE_TOKEN for enterprise features
- See TOPOLOGIES.md for default credentials

### Configuration
- MariaDB must bind to private IP (192.168.56.0/24), NOT localhost
- Port: 3306
- Binary logging enabled for replication
- Proper server_id configuration for replication/Galera

### Replication Setup
- Primary: Enable binary logging, create replication user
- Replicas: Configure CHANGE MASTER TO, start slave
- Verify with SHOW SLAVE STATUS

### Galera Cluster Setup
- Install galera-enterprise-4
- Configure wsrep_cluster_address with all node IPs
- Bootstrap first node with --wsrep-new-cluster
- Verify cluster size with wsrep_cluster_size

### Verification Commands
```bash
# Service status
systemctl is-active mariadb

# Bind address
ss -lntp | grep 3306

# Authentication
mariadb -uadmin -pmariadb -h <IP> -e "SELECT 1;"

# Version
mariadb -uadmin -pmariadb -e "SELECT VERSION();"

# Replication status
mariadb -uadmin -pmariadb -e "SHOW SLAVE STATUS\G"

# Galera status
mariadb -uadmin -pmariadb -e "SHOW STATUS LIKE 'wsrep_%';"
```

## Common Issues
- MariaDB listening on 127.0.0.1 instead of private IP → Fix bind_address in my.cnf
- Replication fails → Check server_id uniqueness, binary logging enabled
- Galera won't join cluster → Verify wsrep_cluster_address, bootstrap first node
- Authentication fails → Verify admin user created, password set correctly

## Related Files
- `provision/common.sh` - System setup
- `provision/primary.sh` - Primary replication setup
- `provision/replica.sh` - Replica replication setup
- `provision/galera.sh` - Galera cluster setup
