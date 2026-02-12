#!/usr/bin/env bash
set -euo pipefail

TOPOLOGIES=(
  "standalone"
  "primary-replica"
  "galera"
  "primary-replica-maxscale"
  "galera-maxscale"
  "mixed-2-maxscale"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-halt}"
shift || true
ARGS="$@"

case "$ACTION" in
  up|halt|destroy|status|ssh|reload|provision)
    echo "Running 'vagrant $ACTION' on all topologies..."
    for topology in "${TOPOLOGIES[@]}"; do
      echo "[$topology] Running: vagrant $ACTION $ARGS"
      (cd "$SCRIPT_DIR/topologies/$topology" && vagrant $ACTION $ARGS)
    done
    echo "Done."
    ;;
  *)
    echo "Usage: $0 <vagrant-command> [arguments...]"
    echo ""
    echo "Examples:"
    echo "  $0 up                    # Start all VMs"
    echo "  $0 halt                  # Halt all VMs (default if no command)"
    echo "  $0 destroy -f            # Destroy all VMs with force flag"
    echo "  $0 status                # Show status of all VMs"
    echo "  $0 provision             # Re-provision all VMs"
    echo ""
    echo "Any vagrant command and arguments are supported."
    exit 1
    ;;
esac
