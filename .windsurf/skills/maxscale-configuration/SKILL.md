---
name: MaxScale Configuration
description: Knowledge and procedures for configuring MaxScale load balancer
tags: [maxscale, load-balancing, routing]
---

# MaxScale Configuration Skill

## Overview
This skill provides expertise in configuring MaxScale 25.10 for MariaDB load balancing and routing.

## MaxScale Basics

### Version
- **Exact version**: 25.10.1
- Installed from enterprise repository
- Requires ENTERPRISE_TOKEN for enterprise features

### Ports
- Default listener: 4006 (read-write routing)
- Admin port: 8989 (maxctrl)
- Monitor port: varies by configuration

### Default Credentials
- See TOPOLOGIES.md for credentials

## Topologies with MaxScale

### Primary-Replica + MaxScale
- 3 MariaDB servers (1 primary + 2 replicas)
- 1 MaxScale instance
- Router: readwritesplit (write to primary, read from replicas)
- Service: Read-Write-Service on port 4006

### Galera + MaxScale
- 3 Galera cluster nodes
- 1 MaxScale instance
- Router: readconnroute (round-robin across cluster)
- Service: Read-Write-Service on port 4006

### Mixed-2-MaxScale
- 2 Primary-Replica servers
- 2 Galera cluster nodes
- 2 MaxScale instances
- Services: Read-Write-Service (PR), Galera-Service (Galera)

## Configuration Files

### Location
- `/etc/maxscale/maxscale.cnf` on MaxScale VM

### Key Sections
```ini
[maxscale]
threads=auto
log_warning=true

[MariaDB-Monitor]
type=monitor
module=mariadbmon
servers=<server-list>
user=admin
password=mariadb

[Read-Write-Service]
type=service
router=readwritesplit
servers=<server-list>
user=admin
password=mariadb

[Read-Write-Listener]
type=listener
service=Read-Write-Service
protocol=MariaDBClient
port=4006
```

## Verification Commands

### Service Status
```bash
systemctl is-active maxscale
maxscale --version
```

### Server Status
```bash
maxctrl list servers
maxctrl show server <server-name>
```

### Service Status
```bash
maxctrl list services
maxctrl show service <service-name>
```

### Connection Test
```bash
mariadb -uadmin -pmariadb -h <maxscale-ip> -P 4006 -e "SELECT @@hostname;"
```

## Common Issues
- MaxScale can't connect to backends → Check firewall, server IPs, credentials
- Servers show "Down" status → Verify MariaDB running, replication/cluster healthy
- Read-write routing fails → Check router configuration, service bindings
- Monitor not detecting changes → Verify monitor user permissions, server connectivity

## Related Files
- `provision/maxscale.sh` - Standard MaxScale setup
- `provision/maxscale-mixed.sh` - Mixed topology MaxScale setup
- `TOPOLOGIES.md` - Topology definitions with MaxScale
- `VERIFY.md` - MaxScale verification procedures
