#!/bin/bash
set -e

echo "================================================"
echo "Google Drive Backup Setup for M3 Mac"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if multipass is installed
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}❌ Multipass is not installed.${NC}"
    echo ""
    echo "Please install it with:"
    echo "  brew install multipass"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Multipass is installed${NC}"

# Check if ansible is installed
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}❌ Ansible is not installed.${NC}"
    echo ""
    echo "Please install it with:"
    echo "  brew install ansible"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Ansible is installed${NC}"
echo ""

# Check if VM already exists
if multipass list | grep -q "sandbox"; then
    echo -e "${YELLOW}⚠ VM 'sandbox' already exists${NC}"
    read -p "Do you want to delete it and start fresh? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing VM..."
        multipass delete sandbox
        multipass purge
        echo -e "${GREEN}✓ Old VM deleted${NC}"
    else
        echo "Using existing VM..."
    fi
fi

# Create the VM if it doesn't exist
if ! multipass list | grep -q "sandbox"; then
    echo ""
    echo "Creating Ubuntu VM (this may take 2-3 minutes)..."
    multipass launch 22.04 --name sandbox --memory 2G --disk 10G --cpus 2
    echo -e "${GREEN}✓ VM created${NC}"
else
    echo -e "${GREEN}✓ VM exists${NC}"
    multipass start sandbox 2>/dev/null || true
fi

# Wait a moment for VM to be fully ready
sleep 3

echo ""
echo "Setting up SSH access..."

# Generate SSH key if needed
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo -e "${GREEN}✓ SSH key generated${NC}"
fi

# Set up SSH in the VM
multipass exec sandbox -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
cat ~/.ssh/id_rsa.pub | multipass exec sandbox -- bash -c "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Install and start SSH server
echo "Installing SSH server in VM..."
multipass exec sandbox -- sudo apt-get update -qq
multipass exec sandbox -- sudo apt-get install -y openssh-server -qq
multipass exec sandbox -- sudo systemctl enable ssh
multipass exec sandbox -- sudo systemctl start ssh

echo -e "${GREEN}✓ SSH configured${NC}"

# Get VM IP address
VM_IP=$(multipass info sandbox | grep IPv4 | awk '{print $2}')
echo ""
echo -e "${GREEN}VM IP Address: ${VM_IP}${NC}"

# Create inventory.ini
echo ""
echo "Creating inventory.ini..."
cat > inventory.ini << EOF
[sandbox]
${VM_IP} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_python_interpreter=/usr/bin/python3

[sandbox:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
echo -e "${GREEN}✓ inventory.ini created${NC}"

# Test Ansible connection
echo ""
echo "Testing Ansible connection..."
if ansible -i inventory.ini sandbox -m ping &> /dev/null; then
    echo -e "${GREEN}✓ Ansible can connect to VM${NC}"
else
    echo -e "${RED}❌ Ansible connection failed${NC}"
    echo "Waiting 5 seconds and retrying..."
    sleep 5
    if ansible -i inventory.ini sandbox -m ping &> /dev/null; then
        echo -e "${GREEN}✓ Ansible can connect to VM${NC}"
    else
        echo -e "${RED}❌ Still failing. Please check manually with:${NC}"
        echo "  ansible -i inventory.ini sandbox -m ping"
        exit 1
    fi
fi

# Create dummy credentials if they don't exist
echo ""
if [ ! -f files/credentials.json ]; then
    echo "Creating dummy credentials.json..."
    mkdir -p files
    cat > files/credentials.json << 'EOF'
{
  "type": "service_account",
  "project_id": "dummy-project",
  "private_key_id": "dummy123",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7W8/dummy/key\n-----END PRIVATE KEY-----\n",
  "client_email": "dummy-service-account@dummy-project.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/dummy%40dummy.iam.gserviceaccount.com"
}
EOF
    echo -e "${GREEN}✓ Dummy credentials.json created${NC}"
    echo -e "${YELLOW}⚠ This is a dummy file - replace with real credentials when available${NC}"
else
    echo -e "${GREEN}✓ credentials.json already exists${NC}"
fi

# Create test database in VM
echo ""
echo "Creating test SQLite database in VM..."
multipass exec sandbox -- sudo mkdir -p /var/lib/myapp
multipass exec sandbox -- sudo sqlite3 /var/lib/myapp/db.sqlite "CREATE TABLE IF NOT EXISTS test(id INTEGER PRIMARY KEY, name TEXT);"
multipass exec sandbox -- sudo sqlite3 /var/lib/myapp/db.sqlite "INSERT INTO test (name) VALUES ('test_data_$(date +%s)');"
echo -e "${GREEN}✓ Test database created at /var/lib/myapp/db.sqlite${NC}"

# Summary
echo ""
echo "================================================"
echo -e "${GREEN}Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Run the Ansible playbook:"
echo -e "   ${YELLOW}ansible-playbook -i inventory.ini playbook.yml${NC}"
echo ""
echo "2. After the playbook runs, test the backup script:"
echo -e "   ${YELLOW}multipass shell sandbox${NC}"
echo -e "   ${YELLOW}sudo /usr/local/bin/backup_sqlite.sh${NC}"
echo ""
echo "3. When you get real Google Drive credentials:"
echo "   - Replace files/credentials.json with the real file"
echo "   - Share your Drive folder with the service account email"
echo "   - Re-run the playbook"
echo ""
echo "Useful commands:"
echo "  multipass shell sandbox    # SSH into the VM"
echo "  multipass stop sandbox     # Stop the VM"
echo "  multipass start sandbox    # Start the VM"
echo "  multipass info sandbox     # View VM details"
echo ""
echo "For more details, see SETUP_M3_MAC.md"
echo ""
