# Google Drive SQLite Backup System

Automated SQLite database backup system that safely backs up databases to Google Drive using rclone and Ansible.

## 🚨 Important: M3 Mac Users

**VirtualBox does not work on Apple Silicon (M1/M2/M3) Macs!**

If you're on an M3 Mac and got the error:
```
VBoxManage: error: Cannot run the machine because its platform architecture x86 is not supported on ARM
```

✅ **Don't worry!** This project includes a complete alternative setup using **Multipass** instead of Vagrant/VirtualBox.

## 🚀 Quick Start

### For M3 Mac Users (Apple Silicon)

1. **Install prerequisites:**
   ```bash
   brew install multipass ansible
   ```

2. **Run the automated setup:**
   ```bash
   ./setup_m3.sh
   ```

3. **Deploy the backup system:**
   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

4. **Test it:**
   ```bash
   multipass shell sandbox
   sudo /usr/local/bin/backup_sqlite.sh
   ```

👉 **See [QUICKSTART.md](QUICKSTART.md) for detailed steps**

### For x86 Machines (Intel/AMD)

Follow the original Vagrant setup in [initial_project_outline.md](GEMINI_DOCS/initial_project_outline.md)

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[QUICKSTART.md](QUICKSTART.md)** | Fast 5-minute setup guide for M3 Macs |
| **[SETUP_M3_MAC.md](SETUP_M3_MAC.md)** | Detailed M3 setup with troubleshooting |
| **[initial_project_outline.md](GEMINI_DOCS/initial_project_outline.md)** | Original project design (Vagrant/VirtualBox) |

## 🔧 What This Does

This system provides **automated, safe SQLite database backups** with these features:

- ✅ **Safe hot backups** using SQLite's `VACUUM INTO` (no long locks)
- ✅ **Automatic uploads** to Google Drive using rclone
- ✅ **Scheduled daily backups** via cron
- ✅ **Automatic retention** (deletes backups older than 30 days)
- ✅ **Transaction-safe** backup process
- ✅ **Infrastructure as Code** using Ansible

## 📁 Project Structure

```
gdrive_backup_test/
├── README.md                    # This file
├── QUICKSTART.md                # Fast setup guide
├── SETUP_M3_MAC.md              # Detailed M3 Mac guide
├── setup_m3.sh                  # Automated setup script ⭐
├── diagnose.sh                  # Diagnostic tool
├── inventory.ini                # Ansible inventory (auto-generated)
├── playbook.yml                 # Ansible playbook (main config)
├── files/
│   └── credentials.json         # Google service account credentials
├── templates/
│   ├── backup_script.sh.j2      # Backup script template
│   └── rclone.conf.j2           # Rclone configuration template
└── GEMINI_DOCS/
    └── initial_project_outline.md
```

## 🛠️ Helpful Commands

### VM Management
```bash
./setup_m3.sh                 # Initial setup (creates VM)
./diagnose.sh                 # Check system health
multipass shell sandbox       # SSH into VM
multipass list                # View all VMs
multipass stop sandbox        # Stop the VM
multipass start sandbox       # Start the VM
```

### Deployment
```bash
ansible-playbook -i inventory.ini playbook.yml    # Deploy/update
ansible -i inventory.ini sandbox -m ping          # Test connection
```

### Testing
```bash
multipass shell sandbox
sudo /usr/local/bin/backup_sqlite.sh             # Manual backup
tail -f /var/log/db_backup.log                   # View logs
```

## 🔐 Google Drive Setup

Since you don't have Google Drive API keys yet, the system is currently using **dummy credentials**. 

When you're ready:

1. **Create a Google Cloud project** and enable the Drive API
2. **Create a service account** and download the JSON key
3. **Replace the dummy credentials:**
   ```bash
   cp ~/Downloads/your-key.json files/credentials.json
   ```
4. **Share your Drive folder** with the service account email (found in the JSON)
5. **Re-run the playbook:**
   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

## 🔍 Troubleshooting

### Quick diagnostics:
```bash
./diagnose.sh
```

This script checks:
- ✓ Prerequisites installed
- ✓ VM status and connectivity
- ✓ Required files present
- ✓ Ansible can connect
- ✓ Services deployed correctly

### Common Issues

**"VM won't start"**
```bash
multipass restart sandbox
```

**"Ansible can't connect"**
```bash
./setup_m3.sh    # Regenerates SSH config and inventory
```

**"IP address changed"**
```bash
./setup_m3.sh    # Updates inventory.ini with new IP
```

**"Start completely fresh"**
```bash
multipass delete sandbox
multipass purge
./setup_m3.sh
ansible-playbook -i inventory.ini playbook.yml
```

## 🎯 How It Works

1. **Ansible** configures an Ubuntu VM with all required packages
2. **Backup script** runs daily via cron (2:30 AM by default)
3. **Script performs:**
   - Creates transaction-safe SQLite backup using `VACUUM INTO`
   - Uploads to Google Drive using rclone
   - Deletes local copy
   - Cleans up old cloud backups (30+ days)
4. **Logs** are written to `/var/log/db_backup.log`

## 🚀 Next Steps

1. ✅ Run `./setup_m3.sh` to create the VM
2. ✅ Run the playbook to configure everything
3. ✅ Test with dummy credentials
4. 🔜 Get real Google Drive credentials
5. 🔜 Update credentials and re-run playbook
6. 🔜 Deploy to production server (same playbook!)

## 📊 System Requirements

- **macOS** with Apple Silicon (M1/M2/M3) or Intel
- **4GB RAM** available for VM
- **10GB disk space** for VM
- **Homebrew** package manager
- **Internet connection** for package downloads

## ℹ️ About

This project demonstrates:
- Infrastructure as Code with Ansible
- Safe database backup strategies
- Google Drive integration via service accounts
- Cross-platform virtualization (Multipass vs VirtualBox)
- ARM/Apple Silicon compatibility solutions

## 📝 License

This is a demonstration/learning project. Use and modify as needed.

---

**Having issues?** Check:
1. [QUICKSTART.md](QUICKSTART.md) for step-by-step instructions
2. [SETUP_M3_MAC.md](SETUP_M3_MAC.md) for detailed troubleshooting
3. Run `./diagnose.sh` to identify problems automatically