---
name: Vagrant Topology Management
description: Knowledge and procedures for managing Vagrant-based topologies
tags: [vagrant, topology, infrastructure]
---

# Vagrant Topology Management Skill

## Overview
This skill provides expertise in managing Vagrant topologies for MariaDB infrastructure.

## Project Structure

### Directory Layout
```
topologies/
├── Vagrantfile              (Shared - single source of truth)
├── standalone/
│   ├── Vagrantfile          (Symlink → ../Vagrantfile)
│   └── config.yaml          (Topology definition)
├── primary-replica/
├── galera/
├── primary-replica-maxscale/
├── galera-maxscale/
└── mixed-2-maxscale/
```

### DRY Principle
- Single `topologies/Vagrantfile` contains all provisioning logic
- Each topology directory has only `config.yaml` + symlink
- Changes to provisioning logic made in one place

## Topology Definitions

See `TOPOLOGIES.md` for:
- Complete topology definitions and VM counts
- IP assignments for each topology
- Network configuration and credentials
- Common VM settings (RAM, CPUs, ports)

## Common Commands

### Using vm-ctrl.sh (All Topologies)
```bash
./vm-ctrl.sh up              # Start all topologies
./vm-ctrl.sh halt            # Halt all topologies
./vm-ctrl.sh destroy -f      # Destroy all topologies
./vm-ctrl.sh status          # Show status of all topologies
```

### Individual Topology
```bash
cd topologies/standalone
vagrant up                   # Start VMs in this topology
vagrant halt                 # Stop VMs
vagrant destroy -f           # Destroy VMs
vagrant ssh <vm-name>        # SSH into a VM
vagrant status               # Show VM status
```

## Configuration Files

### config.yaml Structure
```yaml
topology: standalone
nodes:
  - name: sa-server-0
    ip: 192.168.56.10
    role: standalone
    server_id: 1
```

### Vagrantfile Logic
- Reads `config.yaml` from current directory
- Loads ENTERPRISE_TOKEN from root `.env`
- Computes derived values (primary_ip, galera_ips, etc.)
- Provisions based on node role

## Verification
- All VMs must have fixed private IPs
- All services must be accessible from host
- Provisioning must be fully automated
- No manual VM intervention required

## Related Files
- `topologies/Vagrantfile` - Shared provisioning logic
- `topologies/*/config.yaml` - Topology definitions
- `vm-ctrl.sh` - Master control script
- `TOPOLOGIES.md` - Topology reference
