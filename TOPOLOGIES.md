# MariaDB Vagrant Topologies

## Network
- Private network: 192.168.56.0/24
- Provider: libvirt private network
- All services must bind to the private IP.

## Common VM Settings
- OS: Ubuntu LTS
- RAM: 2048 MB
- CPUs: 2
- MariaDB port: 3306
- MaxScale port: 4006

## Credentials
- User: admin
- Password: mariadb

---

## Topologies

### 1. standalone
- sa-server-0: 192.168.56.10

### 2. primary-replica (3 nodes)
- pr-primary: 192.168.56.11
- pr-replica-1: 192.168.56.12
- pr-replica-2: 192.168.56.13

### 3. primary-replica-maxscale
- prm-primary: 192.168.56.21
- prm-replica-1: 192.168.56.22
- prm-replica-2: 192.168.56.23
- prm-maxscale: 192.168.56.24

### 4. galera
- ga-server-1: 192.168.56.31
- ga-server-2: 192.168.56.32
- ga-server-3: 192.168.56.33

### 5.galera-maxscale
- gam-server-1: 192.168.56.41
- gam-server-2: 192.168.56.42
- gam-server-3: 192.168.56.43
- gam-maxscale: 192.168.56.44

### 6. mixed-2-maxscale
- m2m-primary: 192.168.56.51
- m2m-replica: 192.168.56.52
- m2m-galera-1: 192.168.56.53
- m2m-galera-2: 192.168.56.54
- m2m-maxscale-1: 192.168.56.55
- m2m-maxscale-2: 192.168.56.56
