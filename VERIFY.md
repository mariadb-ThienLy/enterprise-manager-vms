## Purpose
This document defines mandatory verification checks for all MariaDB Vagrant topologies.
Provisioning MUST NOT be considered successful unless all applicable checks pass.

---

## Global Preconditions (All Topologies)

### 1. VM Reachability
From host:
```

ping -c 1 <VM_IP>

```
Expected:
- Packet received
- No packet loss

---

### 2. MariaDB Service Status
On VM:
```

systemctl is-active mariadb

```
Expected:
```

active

```

---

### 3. MariaDB Bind Address
On VM:
```

ss -lntp | grep 3306

```
Expected:
- MariaDB listening on the private IP
- NOT only on 127.0.0.1

---

### 4. Authentication
From host:
```

mariadb -uadmin -pmariadb -h <VM_IP> -e "SELECT 1;"

```
Expected:
```

1

```

---

### 5. Version Verification
On any MariaDB node:
```

mariadb -uadmin -pmariadb -e "SELECT VERSION();"

```
Expected:
- MariaDB LTS
- NOT MySQL

---

## Standalone Topology

### 6. Standalone Connectivity
From host:
```

mariadb -uadmin -pmariadb -h 192.168.56.10 -e "SHOW DATABASES;"

```
Expected:
- Query succeeds

---

## Primary–Replica Topology

### 7. Primary Binary Logging
On primary:
```

mariadb -uadmin -pmariadb -e "SHOW VARIABLES LIKE 'log_bin';"

```
Expected:
```

log_bin | ON

```

---

### 8. Replica Replication State
On each replica:
```

mariadb -uadmin -pmariadb -e "SHOW SLAVE STATUS\G"

```
Expected:
```

Slave_IO_Running: Yes
Slave_SQL_Running: Yes

```

---

## Primary–Replica + MaxScale

### 9. MaxScale Service
On MaxScale VM:
```

systemctl is-active maxscale

```
Expected:
```

active

```

---

### 10. MaxScale Version
On MaxScale VM:
```

maxscale --version

```
Expected:
```

25.10.1

```

---

### 11. MaxScale Routing
From host:
```

mariadb -uadmin -pmariadb -h 192.168.56.24 -P 4006 -e "SELECT @@hostname;"

```
Expected:
- Query succeeds

---

## Galera Topology

### 12. Galera Cluster Size
On any Galera node:
```

mariadb -uadmin -pmariadb -e "SHOW STATUS LIKE 'wsrep_cluster_size';"

```
Expected:
```

3

```

---

### 13. Galera Ready State
On each Galera node:
```

mariadb -uadmin -pmariadb -e "SHOW STATUS LIKE 'wsrep_ready';"

```
Expected:
```

ON

```

---

## Galera + MaxScale

### 14. MaxScale Service
On MaxScale VM:
```

systemctl is-active maxscale

```
Expected:
```

active

```

---

### 15. Galera Backend State
On MaxScale VM:
```

maxctrl list servers

```
Expected:
- All servers running

---

### 16. End-to-End Galera Query
From host:
```

mariadb -uadmin -pmariadb -h 192.168.56.44 -P 4006 -e "SHOW STATUS LIKE 'wsrep_cluster_size';"

```
Expected:
```

3

```

---

## Definition of Done
- All applicable checks pass
- No manual VM changes
- Reproducible after destroy/up


