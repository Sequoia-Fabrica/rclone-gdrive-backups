#!/bin/bash

# Helper script for common operations
# Usage: ./helper.sh [command]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Google Drive Backup Helper                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Common commands:"
    echo ""
    echo -e "${GREEN}Setup & Deployment:${NC}"
    echo "  ./helper.sh setup          - Run initial setup"
    echo "  ./helper.sh deploy         - Run Ansible playbook"
    echo "  ./helper.sh check          - Run diagnostics"
    echo ""
    echo -e "${GREEN}VM Management:${NC}"
    echo "  ./helper.sh start          - Start the VM"
    echo "  ./helper.sh stop           - Stop the VM"
    echo "  ./helper.sh restart        - Restart the VM"
    echo "  ./helper.sh shell          - SSH into the VM"
    echo "  ./helper.sh info           - Show VM info"
    echo "  ./helper.sh delete         - Delete VM (start fresh)"
    echo ""
    echo -e "${GREEN}Testing & Logs:${NC}"
    echo "  ./helper.sh test           - Run backup script manually"
    echo "  ./helper.sh logs           - View backup logs"
    echo "  ./helper.sh cron           - Check cron schedule"
    echo "  ./helper.sh db             - Check database status"
    echo ""
    echo -e "${GREEN}Configuration:${NC}"
    echo "  ./helper.sh ip             - Get VM IP address"
    echo "  ./helper.sh ping           - Test Ansible connection"
    echo "  ./helper.sh update-ip      - Update inventory with new IP"
    echo ""
    echo "Run './helper.sh [command]' or just './helper.sh' to see this menu"
    echo ""
}

cmd_setup() {
    echo -e "${BLUE}Running initial setup...${NC}"
    ./setup_m3.sh
}

cmd_deploy() {
    echo -e "${BLUE}Deploying with Ansible...${NC}"
    ansible-playbook -i inventory.ini playbook.yml
}

cmd_check() {
    echo -e "${BLUE}Running diagnostics...${NC}"
    ./diagnose.sh
}

cmd_start() {
    echo -e "${BLUE}Starting VM...${NC}"
    multipass start sandbox
    echo -e "${GREEN}✓ VM started${NC}"
}

cmd_stop() {
    echo -e "${BLUE}Stopping VM...${NC}"
    multipass stop sandbox
    echo -e "${GREEN}✓ VM stopped${NC}"
}

cmd_restart() {
    echo -e "${BLUE}Restarting VM...${NC}"
    multipass restart sandbox
    echo -e "${GREEN}✓ VM restarted${NC}"
    echo "Waiting for SSH to be ready..."
    sleep 5
}

cmd_shell() {
    echo -e "${BLUE}Opening shell in VM...${NC}"
    multipass shell sandbox
}

cmd_info() {
    multipass info sandbox
}

cmd_delete() {
    echo -e "${RED}WARNING: This will delete the VM and all its data!${NC}"
    read -p "Are you sure? Type 'yes' to continue: " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Deleting VM..."
        multipass delete sandbox
        multipass purge
        echo -e "${GREEN}✓ VM deleted${NC}"
        echo ""
        echo "To start fresh, run: ./helper.sh setup"
    else
        echo "Cancelled."
    fi
}

cmd_test() {
    echo -e "${BLUE}Running backup script manually...${NC}"
    echo ""
    multipass exec sandbox -- sudo /usr/local/bin/backup_sqlite.sh
    echo ""
    echo -e "${GREEN}Done!${NC}"
    echo "Check logs with: ./helper.sh logs"
}

cmd_logs() {
    echo -e "${BLUE}Showing last 50 lines of backup logs...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""
    multipass exec sandbox -- sudo tail -f /var/log/db_backup.log
}

cmd_cron() {
    echo -e "${BLUE}Checking cron schedule...${NC}"
    echo ""
    multipass exec sandbox -- sudo crontab -l | grep -A2 -B2 backup || echo "No backup cron job found"
}

cmd_db() {
    echo -e "${BLUE}Database status:${NC}"
    echo ""
    if multipass exec sandbox -- test -f /var/lib/myapp/db.sqlite; then
        echo -e "${GREEN}✓ Database exists${NC}"
        SIZE=$(multipass exec sandbox -- ls -lh /var/lib/myapp/db.sqlite | awk '{print $5}')
        echo "  Location: /var/lib/myapp/db.sqlite"
        echo "  Size: $SIZE"
        echo ""
        echo "Sample data:"
        multipass exec sandbox -- sudo sqlite3 /var/lib/myapp/db.sqlite "SELECT * FROM test LIMIT 5;" 2>/dev/null || echo "  (cannot read database content)"
    else
        echo -e "${RED}✗ Database not found${NC}"
        echo "  Expected location: /var/lib/myapp/db.sqlite"
    fi
}

cmd_ip() {
    echo -e "${BLUE}VM IP address:${NC}"
    IP=$(multipass info sandbox 2>/dev/null | grep IPv4 | awk '{print $2}')
    if [ -n "$IP" ]; then
        echo -e "${GREEN}$IP${NC}"
    else
        echo -e "${RED}Could not get IP (is VM running?)${NC}"
    fi
}

cmd_ping() {
    echo -e "${BLUE}Testing Ansible connection...${NC}"
    ansible -i inventory.ini sandbox -m ping
}

cmd_update_ip() {
    echo -e "${BLUE}Updating inventory.ini with current VM IP...${NC}"

    if ! multipass list | grep -q "sandbox.*Running"; then
        echo -e "${RED}VM is not running. Start it first:${NC}"
        echo "  ./helper.sh start"
        exit 1
    fi

    VM_IP=$(multipass info sandbox | grep IPv4 | awk '{print $2}')

    if [ -z "$VM_IP" ]; then
        echo -e "${RED}Could not get VM IP address${NC}"
        exit 1
    fi

    cat > inventory.ini << EOF
[sandbox]
${VM_IP} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_python_interpreter=/usr/bin/python3

[sandbox:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

    echo -e "${GREEN}✓ Updated inventory.ini with IP: ${VM_IP}${NC}"
    echo ""
    echo "Testing connection..."
    ansible -i inventory.ini sandbox -m ping
}

# Main script logic
case "${1:-}" in
    setup)
        cmd_setup
        ;;
    deploy)
        cmd_deploy
        ;;
    check)
        cmd_check
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    shell)
        cmd_shell
        ;;
    info)
        cmd_info
        ;;
    delete)
        cmd_delete
        ;;
    test)
        cmd_test
        ;;
    logs)
        cmd_logs
        ;;
    cron)
        cmd_cron
        ;;
    db)
        cmd_db
        ;;
    ip)
        cmd_ip
        ;;
    ping)
        cmd_ping
        ;;
    update-ip)
        cmd_update_ip
        ;;
    help|--help|-h)
        show_menu
        ;;
    *)
        if [ -n "${1:-}" ]; then
            echo -e "${RED}Unknown command: $1${NC}"
        fi
        show_menu
        ;;
esac
