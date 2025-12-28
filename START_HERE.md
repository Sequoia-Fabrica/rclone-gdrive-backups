# 🎯 START HERE - Google Drive SQLite Backup System

Welcome! This guide will get you up and running in **5 minutes**.

## 🚨 Important: You're on an M3 Mac!

VirtualBox **does not work** on Apple Silicon (M1/M2/M3). The error you encountered:
```
VBoxManage: error: Cannot run the machine because its platform 
architecture x86 is not supported on ARM
```

✅ **Good news!** This project is now configured for **Multipass**, which works perfectly on your M3 Mac.

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Prerequisites (2 minutes)

```bash
brew install multipass ansible
```

### Step 2: Run Automated Setup (2 minutes)

```bash
cd gdrive_backup_test
./setup_m3.sh
```

This creates an Ubuntu VM, sets up SSH, and prepares everything.

### Step 3: Deploy the System (1 minute)

```bash
ansible-playbook -i inventory.ini playbook.yml
```

This installs packages, deploys the backup script, and schedules daily backups.

### Step 4: Test It!

```bash
./helper.sh test
```

**Expected result:** Backup is created locally but upload fails (you don't have real Google Drive credentials yet - that's normal!).

---

## ✅ What Just Happened?

You now have:
- ✅ Ubuntu VM running on your M3 Mac
- ✅ SQLite database with test data
- ✅ Backup script deployed
- ✅ Daily backups scheduled (2:30 AM)
- ✅ Everything ready for Google Drive integration

The system is **fully configured** except for Google Drive credentials.

---

## 🔐 Next: Get Google Drive Working

Since you don't have Google Drive API keys yet, the system is using dummy credentials. When you're ready:

### 1. Get Credentials from Google Cloud
- Create a project
- Enable Google Drive API
- Create a service account
- Download JSON key file

### 2. Replace Dummy Credentials
```bash
cp ~/Downloads/your-real-key.json files/credentials.json
```

### 3. Share Drive Folder
- Open `files/credentials.json`
- Copy the `client_email` value
- Go to Google Drive → Create folder `sqlite_backups`
- Share folder with that email address (Editor access)

### 4. Redeploy
```bash
ansible-playbook -i inventory.ini playbook.yml
```

### 5. Test with Real Credentials
```bash
./helper.sh test
```

This time it should upload to Google Drive! 🎉

---

## 📚 Documentation

| Document | What It's For |
|----------|---------------|
| **[QUICKSTART.md](QUICKSTART.md)** | Step-by-step setup (you just did this!) |
| **[README.md](README.md)** | Project overview and features |
| **[COMMANDS.md](COMMANDS.md)** | Command reference/cheat sheet |
| **[SETUP_M3_MAC.md](SETUP_M3_MAC.md)** | Detailed M3 Mac setup & troubleshooting |
| **[WORKFLOW.md](WORKFLOW.md)** | Architecture diagrams & how it works |

---

## 🛠️ Useful Commands

```bash
# Interactive helper menu (RECOMMENDED!)
./helper.sh

# Common operations
./helper.sh shell          # SSH into VM
./helper.sh test           # Run backup manually
./helper.sh logs           # View backup logs
./helper.sh check          # Run diagnostics

# VM management
multipass list             # List VMs
multipass shell sandbox    # SSH into VM
multipass stop sandbox     # Stop VM
multipass start sandbox    # Start VM
```

---

## 🔍 Troubleshooting

### "Something's not working!"

Run diagnostics:
```bash
./diagnose.sh
```

This checks everything and tells you exactly what's wrong.

### "I want to start fresh"

```bash
multipass delete sandbox
multipass purge
./setup_m3.sh
ansible-playbook -i inventory.ini playbook.yml
```

### "Need more help"

Check [SETUP_M3_MAC.md](SETUP_M3_MAC.md) for detailed troubleshooting.

---

## 🎯 What This System Does

- **Safely backs up** SQLite databases (no long locks)
- **Uploads to Google Drive** using rclone
- **Runs automatically** every day at 2:30 AM
- **Deletes old backups** after 30 days
- **Logs everything** to `/var/log/db_backup.log`

---

## 💡 Key Points

### Why Multipass instead of Vagrant?
Multipass works natively on ARM (M3), while VirtualBox doesn't support ARM architecture.

### Can I use this on Intel Macs?
Yes! Multipass works on Intel Macs too. You could also use the original Vagrant/VirtualBox setup.

### Where's my database?
The test database is at `/var/lib/myapp/db.sqlite` inside the VM. You can customize this in `playbook.yml`.

### How do I deploy to production?
Same playbook! Just update `inventory.ini` with your production server:
```ini
[production]
your-server.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your_key
```

Then: `ansible-playbook -i inventory.ini playbook.yml`

---

## 🎓 Learning Path

1. ✅ **You are here** - Basic setup complete
2. 🔜 Get Google Drive credentials
3. 🔜 Test full backup cycle
4. 🔜 Understand how it works ([WORKFLOW.md](WORKFLOW.md))
5. 🔜 Deploy to production server
6. 🔜 Monitor and maintain

---

## 🆘 Quick Help

```bash
# Something wrong? Run diagnostics
./diagnose.sh

# Need to see all commands?
./helper.sh

# Want detailed docs?
# See README.md, QUICKSTART.md, or SETUP_M3_MAC.md

# Stuck? Check logs
./helper.sh logs
```

---

## ✨ You're All Set!

The system is ready. Once you add real Google Drive credentials, backups will start running automatically every day.

**Recommended next step:** Explore the system with `./helper.sh` to see what you can do!

---

**Questions?** Check the documentation files listed above. They cover everything from basic commands to advanced troubleshooting.

**Happy backing up! 🚀**