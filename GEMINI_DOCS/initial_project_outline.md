Here is the complete Ansible configuration for **Option 1 (Rclone + Script)**.

This is designed to work immediately with the sandbox you just created.

### **1. Directory Structure**

First, create a folder for your project and arrange your files like this:

```text
backup-project/
├── files/
│   └── credentials.json    <-- Put the file you downloaded from Google Cloud here
├── templates/
│   ├── backup_script.sh.j2
│   └── rclone.conf.j2
├── inventory.ini           <-- Your sandbox connection info
└── playbook.yml

```

---

### **2. The Files**

#### **A. `files/credentials.json**`

* **Action:** Download your Service Account key from Google Cloud Console.
* **Rename it:** Rename the file to `credentials.json` and place it in the `files/` folder.

#### **B. `templates/rclone.conf.j2**`

This tells Rclone how to talk to Google Drive using the service account file we will upload.

```ini
[gdrive]
type = drive
scope = drive
service_account_file = {{ rclone_config_dir }}/service_account.json
team_drive = 

```

#### **C. `templates/backup_script.sh.j2**`

The bash script that performs the logic. We use Jinja2 variables (`{{ }}`) so you can change paths easily in the playbook.

```bash
#!/bin/bash
set -e

# Configuration
DB_PATH="{{ db_path }}"
BACKUP_DIR="{{ backup_staging_dir }}"
REMOTE_NAME="gdrive"
REMOTE_FOLDER="{{ drive_folder_name }}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="db_backup_${TIMESTAMP}.sqlite"

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

# 1. Safe Hot Backup using SQLite VACUUM INTO
# This creates a transaction-safe copy without locking the DB for long
sqlite3 "$DB_PATH" "VACUUM INTO '$BACKUP_DIR/$BACKUP_NAME'"

# 2. Upload to Google Drive
# We reference the config explicitly to avoid environment variable issues in cron
/usr/bin/rclone copy "$BACKUP_DIR/$BACKUP_NAME" "$REMOTE_NAME:$REMOTE_FOLDER" \
  --config {{ rclone_config_dir }}/rclone.conf

# 3. Cleanup Local File
rm "$BACKUP_DIR/$BACKUP_NAME"

# 4. Retention (Optional: Delete cloud backups older than 30 days)
/usr/bin/rclone delete "$REMOTE_NAME:$REMOTE_FOLDER" --min-age 30d \
  --config {{ rclone_config_dir }}/rclone.conf

```

#### **D. `playbook.yml**`

The Ansible logic to tie it all together.

```yaml
---
- name: Configure SQLite Backup to Google Drive
  hosts: sandbox
  become: yes
  vars:
    # --- Configuration ---
    # The location of the database you want to backup
    db_path: "/var/lib/myapp/db.sqlite"
    
    # Where to store the rclone config and credentials on the server
    rclone_config_dir: "/etc/rclone"
    
    # Where to temporarily store the backup before upload
    backup_staging_dir: "/tmp/sqlite_backups"
    
    # The folder name inside Google Drive
    drive_folder_name: "sqlite_backups"
    
    # How often to run (Cron format)
    schedule_hour: "2"
    schedule_minute: "30"

  tasks:
    - name: Install required packages
      apt:
        name:
          - sqlite3
          - rclone
        state: present
        update_cache: yes

    - name: Ensure configuration directory exists
      file:
        path: "{{ rclone_config_dir }}"
        state: directory
        mode: '0700'

    - name: Upload Google Service Account Credentials
      copy:
        src: files/credentials.json
        dest: "{{ rclone_config_dir }}/service_account.json"
        mode: '0600'

    - name: Deploy Rclone Config
      template:
        src: templates/rclone.conf.j2
        dest: "{{ rclone_config_dir }}/rclone.conf"
        mode: '0600'

    - name: Deploy Backup Script
      template:
        src: templates/backup_script.sh.j2
        dest: "/usr/local/bin/backup_sqlite.sh"
        mode: '0755'

    - name: Verify Rclone Connection (Dry Run)
      command: rclone lsd gdrive: --config {{ rclone_config_dir }}/rclone.conf
      register: rclone_check
      changed_when: false
      failed_when: false

    - name: Alert if Rclone connection failed
      debug:
        msg: "WARNING: Rclone could not list files. Check your Service Account permissions."
      when: rclone_check.rc != 0

    - name: Schedule Daily Backup Cron Job
      cron:
        name: "Daily SQLite Backup"
        minute: "{{ schedule_minute }}"
        hour: "{{ schedule_hour }}"
        job: "/usr/local/bin/backup_sqlite.sh >> /var/log/db_backup.log 2>&1"

```

---

### **3. How to Run It**

1. **Ensure your Inventory is ready:**
If you used the **Vagrant** method from the previous step, your `inventory.ini` should look like this:
```ini
[sandbox]
192.168.56.10 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/default/virtualbox/private_key

```


2. **Run the Playbook:**
```bash
ansible-playbook -i inventory.ini playbook.yml

```


3. **Test the Result:**
SSH into your sandbox and trigger the script manually to confirm it works:
```bash
vagrant ssh
sudo /usr/local/bin/backup_sqlite.sh

```


*If it runs without output, check your Google Drive folder. You should see the file!*

### **Important Troubleshooting Note**

If the playbook runs but the manual test fails with an "Access Denied" error from Google, it is almost always because **you forgot to Share the Google Drive folder with the Service Account email address**.

1. Open `files/credentials.json` on your computer.
2. Find the `"client_email"` field.
3. Go to your Google Drive in the browser.
4. Right-click the folder > Share > Paste that email address.
