# Enterprise Manager VMs

A reproducible Vagrant-based infrastructure for deploying and testing multiple MariaDB topologies with optional MaxScale load balancing.

## Overview

This project provides automated provisioning of MariaDB Enterprise Server in various configurations using Vagrant and libvirt. Each topology is self-contained in its own directory with tab-completion support for easy access.

## Supported Topologies

See `TOPOLOGIES.md` for complete topology definitions, IP assignments, and specifications.

## Quick Start

### Prerequisites

- Vagrant 2.4+
- libvirt provider
- 2+ GB RAM per VM (configurable in Vagrantfile)
- MariaDB Enterprise token in `.env` file (required)

### Environment Setup

Create a `.env` file in the project root with your MariaDB Enterprise token:

```bash
ENTERPRISE_TOKEN=your_token_here
```

### Starting VMs

**Start all topologies:**
```bash
./vm-ctrl.sh up
```

**Start a specific topology:**
```bash
cd topologies/standalone
vagrant up
```

## Usage

### VM Control Script

The `vm-ctrl.sh` script manages all topologies at once:

```bash
# Start all VMs
./vm-ctrl.sh up

# Halt all VMs
./vm-ctrl.sh halt

# Destroy all VMs
./vm-ctrl.sh destroy -f

# Check status of all VMs
./vm-ctrl.sh status

# Re-provision all VMs
./vm-ctrl.sh provision

# SSH into a specific VM (from topology directory)
cd topologies/standalone
vagrant ssh sa-server-0
```

### Individual Topology Control

Each topology directory contains a `Vagrantfile` and `config.yaml`:

```bash
cd topologies/primary-replica
vagrant up              # Start all 3 VMs
vagrant halt            # Stop all VMs
vagrant destroy -f      # Destroy all VMs
vagrant status          # Show VM status
```

## Architecture

### Directory Structure

```
enterprise-manager-vms/
├── README.md
├── vm-ctrl.sh                 # Master control script
├── .env                       # Enterprise token (git-ignored)
├── .gitignore
├── provision/                 # Shared provisioning scripts
│   ├── common.sh             # System setup for all VMs
│   ├── standalone.sh         # Standalone MariaDB setup
│   ├── primary.sh            # Primary replication setup
│   ├── replica.sh            # Replica replication setup
│   ├── galera.sh             # Galera cluster setup
│   ├── maxscale.sh           # MaxScale setup
│   └── maxscale-mixed.sh     # MaxScale for mixed topology
└── topologies/
    ├── Vagrantfile           # Shared Vagrantfile template
    ├── standalone/
    │   ├── Vagrantfile       # Symlink to ../Vagrantfile
    │   └── config.yaml       # Topology configuration
    ├── primary-replica/
    ├── galera/
    ├── primary-replica-maxscale/
    ├── galera-maxscale/
    └── mixed-2-maxscale/
```

### How It Works

1. **Shared Vagrantfile**: All topologies use the same `topologies/Vagrantfile` via symlinks
2. **Topology Config**: Each topology directory has a `config.yaml` defining its VMs and roles
3. **DRY Principle**: Provisioning logic is centralized in `provision/` scripts
4. **Fixed IPs**: Each VM has a stable private IP that persists across `vagrant destroy/up`

## Default Credentials

- **MariaDB Admin User**: `admin`
- **MariaDB Admin Password**: `mariadb`
- **Private Network**: `192.168.56.0/24`

### IP Assignments

| Topology | VM Name | IP | Role |
|----------|---------|-----|------|
| standalone | sa-server-0 | 192.168.56.10 | Standalone |
| primary-replica | pr-primary | 192.168.56.11 | Primary |
| | pr-replica-1 | 192.168.56.12 | Replica |
| | pr-replica-2 | 192.168.56.13 | Replica |
| galera | ga-server-1 | 192.168.56.31 | Galera |
| | ga-server-2 | 192.168.56.32 | Galera |
| | ga-server-3 | 192.168.56.33 | Galera |
| primary-replica-maxscale | prm-primary | 192.168.56.21 | Primary |
| | prm-replica-1 | 192.168.56.22 | Replica |
| | prm-replica-2 | 192.168.56.23 | Replica |
| | prm-maxscale | 192.168.56.24 | MaxScale |
| galera-maxscale | gam-server-1 | 192.168.56.41 | Galera |
| | gam-server-2 | 192.168.56.42 | Galera |
| | gam-server-3 | 192.168.56.43 | Galera |
| | gam-maxscale | 192.168.56.44 | MaxScale |
| mixed-2-maxscale | m2m-primary | 192.168.56.51 | Primary |
| | m2m-replica | 192.168.56.52 | Replica |
| | m2m-galera-1 | 192.168.56.53 | Galera |
| | m2m-galera-2 | 192.168.56.54 | Galera |
| | m2m-maxscale-1 | 192.168.56.55 | MaxScale |
| | m2m-maxscale-2 | 192.168.56.56 | MaxScale |

## Verification

After provisioning, each topology is automatically verified:

- MariaDB service status
- Replication/Galera cluster health
- MaxScale service and routing (if applicable)
- Connectivity from host machine

Check `VERIFY.md` for detailed verification procedures.

## Troubleshooting

### VMs fail to start

Check libvirt status:
```bash
virsh list --all
virsh net-list
```

### Provisioning fails

Check VM logs:
```bash
cd topologies/standalone
vagrant ssh sa-server-0
sudo journalctl -u mariadb -n 50
```

### Connection refused errors

Ensure the private network is configured:
```bash
virsh net-dumpxml default
```

### Stale domains

If VMs are stuck, clean up libvirt:
```bash
virsh destroy <domain-name>
virsh undefine <domain-name>
```

## Performance

- **VM Memory**: 2 GB per VM (configurable in Vagrantfile)
- **VM CPUs**: 2 cores per VM (configurable in Vagrantfile)
- **Disk**: 128 GB per VM (sparse allocation)
- **Provisioning Time**: ~5-10 minutes per topology

## Git Workflow

The `.vagrant/` directories are tracked in git to preserve VM state and metadata. This allows:

- Reproducible VM configurations across clones
- Consistent IP assignments
- Preserved replication/cluster state

To exclude `.vagrant/` from future commits, it's already in `.gitignore`.

## Development

### Adding a New Topology

1. Create a new directory under `topologies/`:
   ```bash
   mkdir topologies/my-topology
   ```

2. Create `config.yaml`:
   ```yaml
   topology: my-topology
   nodes:
     - name: my-vm-1
       ip: 192.168.56.XX
       role: primary
       server_id: XX
   ```

3. Create a symlink to the shared Vagrantfile:
   ```bash
   cd topologies/my-topology
   ln -s ../Vagrantfile Vagrantfile
   ```

4. Add provisioning scripts if needed in `provision/` directory

### Modifying Provisioning

Edit scripts in `provision/` directory. Changes apply to all topologies using that script.

## License

Internal use only.

## Support

For issues or questions, refer to:
- `TOPOLOGIES.md` - Detailed topology descriptions
- `VERIFY.md` - Verification procedures
- Provisioning scripts in `provision/` directory
