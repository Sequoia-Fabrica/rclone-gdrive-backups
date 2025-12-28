# Integration Guide for Parent Ansible Playbooks

This guide explains how to integrate the Google Drive backup system into your existing Ansible infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Integration Methods](#integration-methods)
3. [Prerequisites](#prerequisites)
4. [Method 1: Git Clone + Include Tasks](#method-1-git-clone--include-tasks)
5. [Method 2: Git Submodule](#method-2-git-submodule)
6. [Method 3: Ansible Galaxy Role](#method-3-ansible-galaxy-role)
7. [Configuration Management](#configuration-management)
8. [Security Considerations](#security-considerations)
9. [Testing and Validation](#testing-and-validation)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This backup system is designed to be **composable** and **reusable** across multiple projects. You can integrate it into your existing Ansible infrastructure in several ways, depending on your workflow and requirements.

### Architecture

```
Your Infrastructure Repository
├── playbooks/
│   ├── main_playbook.yml           ← Your main playbook
│   └── deploy_production.yml       ← Includes backup deployment
├── inventory/
│   └── production/
│       ├── hosts.ini
│       └── group_vars/
│           └── all.yml             ← Backup configuration
├── files/
│   └── rclone.conf                 ← Your OAuth config (gitignored)
└── [backup system integration]     ← One of the methods below
```

---

## Integration Methods

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Git Clone** | Simple, flexible | Manual updates | Quick integration, testing |
| **Git Submodule** | Version controlled, trackable | Requires git knowledge | Production, version tracking |
| **Ansible Galaxy Role** | Standard Ansible pattern | More setup required | Large organizations |

---

## Prerequisites

Before integrating, ensure you have:

1. **Ansible installed** on your control machine
2. **Docker installed** on target servers (if using Docker deployment)
3. **Rclone configured** with Google Drive OAuth
   ```bash
   rclone config
   # Create a remote named "gdrive" or your preferred name
   ```
4. **Rclone config file** available:
   ```bash
   cp ~/.config/rclone/rclone.conf ./files/rclone.conf
   chmod 600 ./files/rclone.conf
   ```

---

## Method 1: Git Clone + Include Tasks

This is the **simplest and most flexible** method. Your playbook clones this repository and includes the deployment tasks.

### Step 1: Update Your Main Playbook

```yaml
---
# playbooks/deploy_production.yml
- name: Deploy Production Environment
  hosts: production
  become: yes
  vars:
    # Your application vars
    app_name: "myapp"
    app_db_path: "/var/lib/{{ app_name }}/db.sqlite"
    
    # Backup system configuration
    backup_repo_url: "https://github.com/yourorg/gdrive-backup.git"
    backup_repo_version: "main"  # or tag like "v1.0.0"
    backup_repo_dest: "/opt/gdrive-backup"
    
    # Backup settings
    backup_remote_name: "gdrive"
    backup_folder: "{{ app_name }}_backups"
    backup_schedule: "0 3 * * *"  # 3 AM daily

  tasks:
    # ========================================
    # Your existing application deployment
    # ========================================
    - name: Deploy your application
      # ... your tasks ...

    # ========================================
    # Clone and deploy backup system
    # ========================================
    - name: Install git (if not already installed)
      apt:
        name: git
        state: present
      tags: ['backup']

    - name: Clone backup repository
      git:
        repo: "{{ backup_repo_url }}"
        dest: "{{ backup_repo_dest }}"
        version: "{{ backup_repo_version }}"
        force: yes
      tags: ['backup']

    - name: Deploy rclone configuration
      copy:
        src: files/rclone.conf
        dest: /etc/gdrive-backup/rclone.conf
        mode: '0600'
      tags: ['backup']

    - name: Deploy backup container
      import_playbook: "{{ backup_repo_dest }}/deploy_docker.yml"
      vars:
        container_name: "{{ app_name }}_backup"
        db_path: "{{ app_db_path }}"
        rclone_remote_name: "{{ backup_remote_name }}"
        drive_folder_name: "{{ backup_folder }}"
        backup_schedule: "{{ backup_schedule }}"
        rclone_config_path: "/etc/gdrive-backup/rclone.conf"
        run_on_startup: "false"
      tags: ['backup']
```

### Step 2: Create Directory Structure

```bash
# In your infrastructure repository
mkdir -p files/
cp ~/.config/rclone/rclone.conf files/rclone.conf
chmod 600 files/rclone.conf
```

### Step 3: Add to .gitignore

```bash
# In your repository's .gitignore
echo "files/rclone.conf" >> .gitignore
```

### Step 4: Deploy

```bash
# Deploy everything
ansible-playbook playbooks/deploy_production.yml -i inventory/production/hosts.ini

# Deploy only backups
ansible-playbook playbooks/deploy_production.yml -i inventory/production/hosts.ini --tags backup

# Deploy to specific host
ansible-playbook playbooks/deploy_production.yml -i inventory/production/hosts.ini --limit prod-server-1
```

### Pros
- ✅ Simple to set up
- ✅ Easy to test and modify
- ✅ No git submodule complexity
- ✅ Can use specific commits or tags

### Cons
- ❌ Updates require manual intervention
- ❌ Repository cloned on each target server

---

## Method 2: Git Submodule

This method keeps the backup system as a **tracked submodule** in your repository.

### Step 1: Add Submodule

```bash
cd your-infrastructure-repo
git submodule add https://github.com/yourorg/gdrive-backup.git backup-system
git submodule update --init --recursive
```

### Step 2: Update Your Playbook

```yaml
---
# playbooks/deploy_production.yml
- name: Deploy Production Environment
  hosts: production
  become: yes
  vars:
    app_name: "myapp"
    app_db_path: "/var/lib/{{ app_name }}/db.sqlite"
    
    # Backup configuration
    backup_remote_name: "gdrive"
    backup_folder: "{{ app_name }}_backups"
    backup_schedule: "0 3 * * *"

  tasks:
    # Deploy your application
    - name: Deploy application
      # ... your tasks ...

    # Deploy rclone config
    - name: Deploy rclone configuration
      copy:
        src: files/rclone.conf
        dest: /etc/gdrive-backup/rclone.conf
        mode: '0600'
      tags: ['backup']

    # Deploy backup system from submodule
    - name: Deploy backup system
      import_playbook: "../backup-system/deploy_docker.yml"
      vars:
        container_name: "{{ app_name }}_backup"
        db_path: "{{ app_db_path }}"
        rclone_remote_name: "{{ backup_remote_name }}"
        drive_folder_name: "{{ backup_folder }}"
        backup_schedule: "{{ backup_schedule }}"
        rclone_config_path: "/etc/gdrive-backup/rclone.conf"
      tags: ['backup']
```

### Step 3: Clone Your Repository (New Machines)

```bash
git clone --recurse-submodules https://github.com/yourorg/your-infrastructure.git
cd your-infrastructure
```

### Step 4: Update Submodule (Get Latest Changes)

```bash
# Update to latest commit
git submodule update --remote backup-system

# Or update to specific version
cd backup-system
git checkout v1.0.0
cd ..
git add backup-system
git commit -m "Update backup system to v1.0.0"
```

### Pros
- ✅ Version controlled
- ✅ Trackable in git history
- ✅ Can pin to specific versions
- ✅ Standard git workflow

### Cons
- ❌ Requires git submodule knowledge
- ❌ Slightly more complex setup

---

## Method 3: Ansible Galaxy Role

Convert the backup system into an Ansible Galaxy role for maximum reusability.

### Step 1: Create Role Structure

```bash
# In the backup repository
mkdir -p roles/gdrive_backup/{tasks,defaults,files,templates,handlers}

# Move files
mv deploy_docker.yml roles/gdrive_backup/tasks/main.yml
mv scripts roles/gdrive_backup/files/
mv Dockerfile roles/gdrive_backup/files/
```

### Step 2: Create requirements.yml

```yaml
# requirements.yml in your infrastructure repo
---
roles:
  - src: https://github.com/yourorg/gdrive-backup.git
    version: main
    name: gdrive_backup
```

### Step 3: Install Role

```bash
ansible-galaxy install -r requirements.yml
```

### Step 4: Use in Playbook

```yaml
---
- name: Deploy Production Environment
  hosts: production
  become: yes
  vars:
    app_db_path: "/var/lib/myapp/db.sqlite"
  
  roles:
    - role: gdrive_backup
      vars:
        db_path: "{{ app_db_path }}"
        rclone_remote_name: "gdrive"
        drive_folder_name: "myapp_backups"
        backup_schedule: "0 3 * * *"
        rclone_config_path: "/etc/gdrive-backup/rclone.conf"
```

### Pros
- ✅ Standard Ansible pattern
- ✅ Easy to share across organizations
- ✅ Version management via Galaxy
- ✅ Reusable across multiple projects

### Cons
- ❌ Requires restructuring
- ❌ More initial setup

---

## Configuration Management

### Using Group Variables

Organize configuration in `group_vars`:

```yaml
# inventory/production/group_vars/all.yml
---
# Backup system configuration
backup_system:
  enabled: true
  repository: "https://github.com/yourorg/gdrive-backup.git"
  version: "v1.0.0"
  
  # Rclone configuration
  rclone:
    remote_name: "gdrive"
    config_source: "{{ playbook_dir }}/../files/rclone.conf"
    config_dest: "/etc/gdrive-backup/rclone.conf"
  
  # Backup settings
  schedule: "0 3 * * *"
  retention_days: 30
  run_on_startup: false

# Application-specific backup settings
applications:
  myapp:
    db_path: "/var/lib/myapp/db.sqlite"
    backup_folder: "myapp_backups"
  
  otherapp:
    db_path: "/var/lib/otherapp/db.sqlite"
    backup_folder: "otherapp_backups"
```

### Using in Playbook

```yaml
---
- name: Deploy with backup system
  hosts: production
  become: yes
  
  tasks:
    - name: Deploy backup for each application
      include_role:
        name: gdrive_backup
      vars:
        container_name: "{{ item.key }}_backup"
        db_path: "{{ item.value.db_path }}"
        rclone_remote_name: "{{ backup_system.rclone.remote_name }}"
        drive_folder_name: "{{ item.value.backup_folder }}"
        backup_schedule: "{{ backup_system.schedule }}"
        rclone_config_path: "{{ backup_system.rclone.config_dest }}"
      loop: "{{ applications | dict2items }}"
      when: backup_system.enabled
```

---

## Security Considerations

### 1. Protect Rclone Configuration

```yaml
- name: Deploy rclone config with proper permissions
  copy:
    src: "{{ backup_system.rclone.config_source }}"
    dest: "{{ backup_system.rclone.config_dest }}"
    mode: '0600'
    owner: root
    group: root
  no_log: true  # Don't log sensitive operations
```

### 2. Use Ansible Vault for Sensitive Data

```bash
# Encrypt rclone.conf
ansible-vault encrypt files/rclone.conf

# Encrypt variables
ansible-vault encrypt_string 'gdrive' --name 'backup_remote_name'
```

### 3. Restrict File Access

```yaml
- name: Create backup config directory
  file:
    path: /etc/gdrive-backup
    state: directory
    mode: '0700'
    owner: root
    group: root
```

### 4. Use Read-Only Mounts

Always mount databases as read-only in containers:

```yaml
volumes:
  - "{{ db_path }}:/data/db.sqlite:ro"
```

### 5. Separate Credentials by Environment

```
files/
├── rclone-production.conf
├── rclone-staging.conf
└── rclone-development.conf
```

---

## Testing and Validation

### Pre-deployment Validation

```yaml
- name: Validate backup configuration
  hosts: localhost
  gather_facts: no
  
  tasks:
    - name: Check rclone config exists
      stat:
        path: "{{ backup_system.rclone.config_source }}"
      register: rclone_config
      failed_when: not rclone_config.stat.exists
    
    - name: Validate rclone config format
      command: rclone config show --config {{ backup_system.rclone.config_source }}
      changed_when: false
    
    - name: Check backup repository accessibility
      uri:
        url: "{{ backup_system.repository }}"
        status_code: 200
      when: backup_system.repository is match("https?://")
```

### Post-deployment Verification

```yaml
- name: Verify backup system deployment
  hosts: production
  become: yes
  
  tasks:
    - name: Check backup container is running
      community.docker.docker_container_info:
        name: "{{ app_name }}_backup"
      register: container_info
      failed_when: container_info.container.State.Status != "running"
    
    - name: Run test backup
      command: docker exec {{ app_name }}_backup /scripts/backup_sqlite.sh
      register: test_backup
      changed_when: false
    
    - name: Verify backup in Google Drive
      command: >
        rclone ls {{ backup_remote_name }}:{{ backup_folder }}
        --config /etc/gdrive-backup/rclone.conf
      changed_when: false
```

---

## Troubleshooting

### Common Issues

#### 1. "Repository not found" when cloning

**Problem:** Git clone fails during playbook execution

**Solution:**
```yaml
- name: Clone backup repository
  git:
    repo: "{{ backup_repo_url }}"
    dest: "{{ backup_repo_dest }}"
    version: "{{ backup_repo_version }}"
    force: yes
    accept_hostkey: yes  # Add this for SSH URLs
```

#### 2. "Rclone config not found"

**Problem:** Container fails to start, can't find rclone.conf

**Solution:**
```bash
# Verify file exists locally
ls -la files/rclone.conf

# Check deployment task
ansible-playbook playbooks/deploy.yml -i inventory.ini --check -v

# Manually copy to verify connectivity
scp files/rclone.conf user@server:/etc/gdrive-backup/rclone.conf
```

#### 3. "Docker module not found"

**Problem:** `community.docker.docker_container` fails

**Solution:**
```bash
# Install Docker collection
ansible-galaxy collection install community.docker

# Or add to requirements.yml
---
collections:
  - name: community.docker
    version: ">=2.0.0"
```

#### 4. Submodule not updating

**Problem:** Submodule stuck at old commit

**Solution:**
```bash
# Force update
git submodule update --init --recursive --remote

# Or reset submodule
git submodule deinit -f backup-system
git submodule update --init
```

#### 5. Permission denied on rclone.conf

**Problem:** Container can't read rclone config

**Solution:**
```yaml
- name: Fix rclone config permissions
  file:
    path: /etc/gdrive-backup/rclone.conf
    mode: '0644'  # Make readable (or use 0600 and check container user)
    owner: root
    group: root
```

---

## Multiple Applications Example

Deploy backups for multiple applications:

```yaml
---
- name: Deploy multiple application backups
  hosts: production
  become: yes
  
  vars:
    backup_configs:
      - name: "webapp"
        db_path: "/var/lib/webapp/db.sqlite"
        schedule: "0 3 * * *"
        folder: "webapp_backups"
      
      - name: "api"
        db_path: "/var/lib/api/db.sqlite"
        schedule: "30 2 * * *"
        folder: "api_backups"
      
      - name: "worker"
        db_path: "/var/lib/worker/db.sqlite"
        schedule: "0 4 * * *"
        folder: "worker_backups"

  tasks:
    - name: Clone backup repository
      git:
        repo: "https://github.com/yourorg/gdrive-backup.git"
        dest: "/opt/gdrive-backup"
        version: "main"
    
    - name: Deploy rclone config
      copy:
        src: files/rclone.conf
        dest: /etc/gdrive-backup/rclone.conf
        mode: '0600'
    
    - name: Deploy backup container for each application
      include_tasks: "/opt/gdrive-backup/deploy_docker.yml"
      vars:
        container_name: "{{ item.name }}_backup"
        db_path: "{{ item.db_path }}"
        rclone_remote_name: "gdrive"
        drive_folder_name: "{{ item.folder }}"
        backup_schedule: "{{ item.schedule }}"
        rclone_config_path: "/etc/gdrive-backup/rclone.conf"
      loop: "{{ backup_configs }}"
```

---

## Best Practices

1. **Version Control Everything**
   - Use git tags for backup system versions
   - Pin to specific versions in production
   - Test updates in staging first

2. **Separate Environments**
   - Use different rclone configs per environment
   - Use different Google Drive folders per environment
   - Consider separate Google accounts per environment

3. **Monitor Deployments**
   - Add verification tasks after deployment
   - Check container logs for errors
   - Verify first backup completes successfully

4. **Document Your Setup**
   - Document which integration method you're using
   - Keep track of version updates
   - Document environment-specific configuration

5. **Test Regularly**
   - Run manual backups after deployment
   - Test restore procedures
   - Validate backups periodically

---

## Next Steps

1. Choose your integration method
2. Test in a staging environment first
3. Review security considerations
4. Deploy to production
5. Monitor and validate
6. Document your specific implementation

For more information:
- [Docker Deployment Guide](DOCKER_DEPLOYMENT.md)
- [Example Parent Playbook](example_parent_playbook.yml)
- [Main README](README.md)