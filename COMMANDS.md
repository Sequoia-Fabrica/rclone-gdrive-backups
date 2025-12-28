# Command Cheat Sheet

Quick reference for common commands. For detailed help, see `README.md`.

## 🚀 Initial Setup

```bash
# Install prerequisites
brew install multipass ansible

# Run automated setup
./setup_m3.sh

# Deploy configuration
ansible-playbook -i inventory.ini playbook.yml
```

## 🎮 Using Helper Script

```bash
# Show all commands
./helper.sh

# Common operations
./helper.sh setup           # Initial setup
./helper.sh deploy          # Run Ansible playbook
./helper.sh check           # Run diagnostics
./helper.sh test            # Test backup manually
./helper.sh logs            # View backup logs
./helper.sh shell           # SSH into VM
```

## 🖥️ VM Management

```bash
# List VMs
multipass list

# Start VM
multipass start sandbox

# Stop VM
multipass stop sandbox

# Restart VM
multipass restart sandbox

# Get VM info (including IP)
multipass info sandbox

# SSH into VM
multipass shell sandbox

# Execute command in VM
multipass exec sandbox -- ls -la

# Delete VM (WARNING: deletes all data)
multipass delete sandbox
multipass purge
```

## 🔧 Ansible Commands

```bash
# Run playbook
ansible-playbook -i inventory.ini playbook.yml

# Run with verbose output
ansible-playbook -i inventory.ini playbook.yml -v

# Test connection
ansible -i inventory.ini sandbox -m ping

# Run ad-hoc command
ansible -i inventory.ini sandbox -m shell -a "uptime"

# Check playbook syntax
ansible-playbook --syntax-check playbook.yml
```

## 📊 Diagnostics

```bash
# Run full diagnostic check
./diagnose.sh

# Check VM status
multipass list
multipass info sandbox

# Test Ansible connection
ansible -i inventory.ini sandbox -m ping

# Get VM IP address
multipass info sandbox | grep IPv4
```

## 🧪 Testing Backups

```bash
# Manual backup test (from host)
multipass exec sandbox -- sudo /usr/local/bin/backup_sqlite.sh

# Manual backup test (inside VM)
multipass shell sandbox
sudo /usr/local/bin/backup_sqlite.sh

# View backup logs
multipass shell sandbox
tail -f /var/log/db_backup.log

# Check last 50 log lines
multipass exec sandbox -- sudo tail -n 50 /var/log/db_backup.log

# Check cron job
multipass exec sandbox -- sudo crontab -l
```

## 📁 File Operations

```bash
# Check if backup script exists
multipass exec sandbox -- ls -l /usr/local/bin/backup_sqlite.sh

# Check database
multipass exec sandbox -- sudo ls -l /var/lib/myapp/db.sqlite

# Check rclone config
multipass exec sandbox -- sudo ls -l /etc/rclone/

# View rclone config
multipass exec sandbox -- sudo cat /etc/rclone/rclone.conf

# Check temp backup directory
multipass exec sandbox -- ls -lh /tmp/sqlite_backups/
```

## 🗄️ Database Commands

```bash
# Inside VM - check database size
sudo ls -lh /var/lib/myapp/db.sqlite

# Query database
sudo sqlite3 /var/lib/myapp/db.sqlite "SELECT * FROM test;"

# Get database info
sudo sqlite3 /var/lib/myapp/db.sqlite ".tables"

# Create test data
sudo sqlite3 /var/lib/myapp/db.sqlite "INSERT INTO test (name) VALUES ('test_$(date +%s)');"
```

## ☁️ Rclone Commands (Inside VM)

```bash
# List Drive root
sudo rclone lsd gdrive: --config /etc/rclone/rclone.conf

# List backup folder
sudo rclone ls gdrive:sqlite_backups --config /etc/rclone/rclone.conf

# Check rclone version
rclone version

# Test Drive connection
sudo rclone about gdrive: --config /etc/rclone/rclone.conf
```

## 🔐 Credentials

```bash
# Check if credentials exist
ls -l files/credentials.json

# View service account email
cat files/credentials.json | grep client_email

# Replace with real credentials
cp ~/Downloads/your-credentials.json files/credentials.json

# Verify format (should show JSON)
python3 -m json.tool files/credentials.json
```

## 📝 Log Management

```bash
# View backup logs
multipass exec sandbox -- sudo tail -f /var/log/db_backup.log

# View last backup
multipass exec sandbox -- sudo tail -n 20 /var/log/db_backup.log

# Search logs for errors
multipass exec sandbox -- sudo grep -i error /var/log/db_backup.log

# Clear logs (if needed)
multipass exec sandbox -- sudo truncate -s 0 /var/log/db_backup.log
```

## 🔄 Update & Redeploy

```bash
# After changing credentials
ansible-playbook -i inventory.ini playbook.yml

# After changing playbook
ansible-playbook -i inventory.ini playbook.yml

# Force redeployment of templates
ansible-playbook -i inventory.ini playbook.yml --tags=deploy

# Update only cron schedule
multipass shell sandbox
sudo crontab -e
```

## 🔍 Troubleshooting

```bash
# VM won't start
multipass restart sandbox
multipass start sandbox

# Can't connect via Ansible
./helper.sh update-ip
ansible -i inventory.ini sandbox -m ping

# Backup script fails
multipass shell sandbox
sudo /usr/local/bin/backup_sqlite.sh
# (Read error messages)

# Check SSH keys
ls -l ~/.ssh/id_rsa*
multipass exec sandbox -- cat ~/.ssh/authorized_keys

# Start completely fresh
multipass delete sandbox
multipass purge
./setup_m3.sh
ansible-playbook -i inventory.ini playbook.yml
```

## 🧹 Cleanup

```bash
# Clean up temp backups in VM
multipass exec sandbox -- sudo rm -rf /tmp/sqlite_backups/*

# Remove old logs
multipass exec sandbox -- sudo truncate -s 0 /var/log/db_backup.log

# Delete VM completely
multipass delete sandbox
multipass purge

# Remove local inventory (will be regenerated)
rm inventory.ini
```

## 📦 Package Management (Inside VM)

```bash
# Update packages
sudo apt-get update

# Upgrade packages
sudo apt-get upgrade

# Check installed version
sqlite3 --version
rclone version

# Reinstall if needed
sudo apt-get install --reinstall sqlite3
sudo apt-get install --reinstall rclone
```

## 🌐 Network & Connectivity

```bash
# Get VM IP
multipass info sandbox | grep IPv4

# Test internet from VM
multipass exec sandbox -- ping -c 3 8.8.8.8

# Test DNS
multipass exec sandbox -- nslookup google.com

# Test Drive API
multipass exec sandbox -- curl -I https://www.googleapis.com
```

## 📊 System Monitoring (Inside VM)

```bash
# Check disk space
df -h

# Check memory
free -h

# Check CPU
top

# Check running processes
ps aux | grep -E 'rclone|sqlite'

# Check cron jobs
sudo crontab -l

# Check cron logs
sudo grep CRON /var/log/syslog | tail -20
```

## 🎯 Production Deployment

```bash
# Update inventory for production
cat > inventory.ini << EOF
[production]
your-server.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your_key
EOF

# Test connection
ansible -i inventory.ini production -m ping

# Deploy to production
ansible-playbook -i inventory.ini playbook.yml

# Monitor production
ssh user@your-server.com tail -f /var/log/db_backup.log
```

## 🔑 One-Liners

```bash
# Quick health check
./diagnose.sh && ./helper.sh test

# Get VM IP quickly
multipass info sandbox | grep IPv4 | awk '{print $2}'

# See last backup result
multipass exec sandbox -- sudo tail -n 1 /var/log/db_backup.log

# Count backups in Drive (from VM)
multipass exec sandbox -- sudo rclone ls gdrive:sqlite_backups --config /etc/rclone/rclone.conf | wc -l

# Full reset
multipass delete sandbox && multipass purge && ./setup_m3.sh && ansible-playbook -i inventory.ini playbook.yml
```

## 🆘 Emergency Commands

```bash
# Backup is failing - run manually to see error
multipass shell sandbox
sudo bash -x /usr/local/bin/backup_sqlite.sh

# Force stop VM
multipass stop sandbox --force

# Can't SSH - reset keys
rm ~/.ssh/known_hosts
./setup_m3.sh

# VM is corrupted - nuclear option
multipass delete sandbox --purge
./setup_m3.sh
```

---

**Need more help?**
- `./helper.sh` - Interactive helper menu
- `./diagnose.sh` - Automated diagnostics
- `README.md` - Project overview
- `QUICKSTART.md` - Setup guide
- `SETUP_M3_MAC.md` - Detailed documentation