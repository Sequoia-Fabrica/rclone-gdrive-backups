#!/bin/bash

# Diagnostic script for Google Drive Backup System on M3 Mac

echo "================================================"
echo "Google Drive Backup System Diagnostics"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

print_section() {
    echo ""
    echo -e "${BLUE}==== $1 ====${NC}"
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

# Check 1: Prerequisites
print_section "Prerequisites"

if command -v multipass &> /dev/null; then
    MULTIPASS_VERSION=$(multipass version | head -n1)
    check_pass "Multipass installed: $MULTIPASS_VERSION"
else
    check_fail "Multipass not installed. Run: brew install multipass"
fi

if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1)
    check_pass "Ansible installed: $ANSIBLE_VERSION"
else
    check_fail "Ansible not installed. Run: brew install ansible"
fi

# Check 2: Required Files
print_section "Required Files"

if [ -f "playbook.yml" ]; then
    check_pass "playbook.yml exists"
else
    check_fail "playbook.yml not found"
fi

if [ -f "files/credentials.json" ]; then
    check_pass "credentials.json exists"
    # Check if it's the dummy file
    if grep -q "dummy-project" files/credentials.json; then
        check_warn "Using dummy credentials (Google Drive uploads won't work)"
    else
        check_pass "Real credentials detected"
    fi
else
    check_fail "credentials.json not found in files/"
fi

if [ -f "templates/backup_script.sh.j2" ]; then
    check_pass "backup_script.sh.j2 exists"
else
    check_fail "backup_script.sh.j2 not found in templates/"
fi

if [ -f "templates/rclone.conf.j2" ]; then
    check_pass "rclone.conf.j2 exists"
else
    check_fail "rclone.conf.j2 not found in templates/"
fi

# Check 3: VM Status
print_section "Virtual Machine Status"

if command -v multipass &> /dev/null; then
    if multipass list 2>/dev/null | grep -q "sandbox"; then
        VM_STATE=$(multipass list | grep sandbox | awk '{print $2}')
        VM_IP=$(multipass info sandbox 2>/dev/null | grep IPv4 | awk '{print $2}')

        if [ "$VM_STATE" = "Running" ]; then
            check_pass "VM 'sandbox' is running"
            check_pass "VM IP: $VM_IP"
        else
            check_fail "VM 'sandbox' exists but is not running (state: $VM_STATE)"
            echo "   Try: multipass start sandbox"
        fi
    else
        check_fail "VM 'sandbox' does not exist"
        echo "   Run: ./setup_m3.sh"
    fi
fi

# Check 4: Inventory File
print_section "Ansible Inventory"

if [ -f "inventory.ini" ]; then
    check_pass "inventory.ini exists"

    if [ -s "inventory.ini" ]; then
        INVENTORY_IP=$(grep -E '^[0-9]' inventory.ini | awk '{print $1}')
        check_pass "Inventory IP: $INVENTORY_IP"

        if [ -n "$VM_IP" ] && [ "$INVENTORY_IP" != "$VM_IP" ]; then
            check_warn "Inventory IP ($INVENTORY_IP) doesn't match VM IP ($VM_IP)"
            echo "   Fix: Run ./setup_m3.sh to regenerate inventory.ini"
        fi
    else
        check_fail "inventory.ini is empty"
        echo "   Fix: Run ./setup_m3.sh"
    fi
else
    check_fail "inventory.ini not found"
    echo "   Fix: Run ./setup_m3.sh"
fi

# Check 5: SSH Key
print_section "SSH Configuration"

if [ -f ~/.ssh/id_rsa ]; then
    check_pass "SSH private key exists (~/.ssh/id_rsa)"
else
    check_warn "SSH private key not found at ~/.ssh/id_rsa"
fi

if [ -f ~/.ssh/id_rsa.pub ]; then
    check_pass "SSH public key exists (~/.ssh/id_rsa.pub)"
else
    check_warn "SSH public key not found"
fi

# Check 6: Ansible Connection
print_section "Ansible Connectivity"

if [ -f "inventory.ini" ] && [ -s "inventory.ini" ] && command -v ansible &> /dev/null; then
    if multipass list 2>/dev/null | grep -q "sandbox.*Running"; then
        echo "Testing Ansible connection (this may take a few seconds)..."
        if ansible -i inventory.ini sandbox -m ping &> /dev/null; then
            check_pass "Ansible can connect to VM"
        else
            check_fail "Ansible cannot connect to VM"
            echo "   Try: multipass restart sandbox && sleep 10"
            echo "   Or: ./setup_m3.sh to reconfigure SSH"
        fi
    else
        check_warn "VM not running, skipping Ansible connection test"
    fi
else
    check_warn "Cannot test Ansible connection (missing prerequisites)"
fi

# Check 7: VM Configuration (if VM is accessible)
if command -v multipass &> /dev/null && multipass list 2>/dev/null | grep -q "sandbox.*Running"; then
    print_section "VM Configuration"

    echo "Checking installed packages in VM..."

    if multipass exec sandbox -- which sqlite3 &> /dev/null; then
        check_pass "sqlite3 installed in VM"
    else
        check_warn "sqlite3 not installed in VM (run playbook)"
    fi

    if multipass exec sandbox -- which rclone &> /dev/null; then
        check_pass "rclone installed in VM"
    else
        check_warn "rclone not installed in VM (run playbook)"
    fi

    if multipass exec sandbox -- test -f /usr/local/bin/backup_sqlite.sh; then
        check_pass "Backup script deployed"
    else
        check_warn "Backup script not found (run playbook)"
    fi

    if multipass exec sandbox -- test -f /var/lib/myapp/db.sqlite; then
        check_pass "Test database exists"
    else
        check_warn "Test database not found"
    fi

    if multipass exec sandbox -- sudo test -f /etc/rclone/rclone.conf; then
        check_pass "Rclone config deployed"
    else
        check_warn "Rclone config not found (run playbook)"
    fi

    if multipass exec sandbox -- sudo crontab -l 2>/dev/null | grep -q backup_sqlite; then
        check_pass "Cron job scheduled"
    else
        check_warn "Cron job not found (run playbook)"
    fi
fi

# Summary
echo ""
echo "================================================"
echo "Summary"
echo "================================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! System is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. If using dummy credentials, replace files/credentials.json with real ones"
    echo "  2. Share Google Drive folder with service account email"
    echo "  3. Run: ansible-playbook -i inventory.ini playbook.yml"
    echo "  4. Test: multipass shell sandbox && sudo /usr/local/bin/backup_sqlite.sh"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ System has $WARNINGS warning(s) but should work${NC}"
    echo ""
    echo "Review warnings above and fix if needed."
else
    echo -e "${RED}✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Recommended action:"
    echo "  Run: ./setup_m3.sh"
fi

echo ""
echo "For more help, see:"
echo "  - QUICKSTART.md (quick setup guide)"
echo "  - SETUP_M3_MAC.md (detailed documentation)"
echo ""

exit $ERRORS
