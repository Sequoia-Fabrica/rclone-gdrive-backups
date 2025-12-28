# -*- mode: ruby -*-
# vi: set ft=ruby :

# This Vagrantfile uses Docker provider which works natively on M1/M2/M3 Macs
# Make sure Docker Desktop is installed and running

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"

  # Fallback to Docker provider
  config.vm.provider "docker" do |d|
    d.image = "ubuntu:22.04"
    d.has_ssh = true
    d.remains_running = true

    # Create a privileged container so systemd/cron work properly
    d.create_args = [
      "--privileged",
      "--cgroupns=host",
      "-v", "/sys/fs/cgroup:/sys/fs/cgroup:rw"
    ]

    # Use a custom Dockerfile to set up SSH
    d.build_dir = "."
    d.dockerfile = <<-DOCKERFILE
      FROM ubuntu:22.04

      # Prevent interactive prompts
      ENV DEBIAN_FRONTEND=noninteractive

      # Install SSH server and other essentials
      RUN apt-get update && \
          apt-get install -y \
            openssh-server \
            sudo \
            python3 \
            systemd \
            systemd-sysv \
            init && \
          apt-get clean

      # Set up SSH
      RUN mkdir -p /var/run/sshd && \
          mkdir -p /root/.ssh && \
          chmod 700 /root/.ssh

      # Create vagrant user
      RUN useradd -m -s /bin/bash vagrant && \
          echo 'vagrant:vagrant' | chpasswd && \
          echo 'vagrant ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

      # Set up SSH for vagrant user
      RUN mkdir -p /home/vagrant/.ssh && \
          chmod 700 /home/vagrant/.ssh && \
          chown vagrant:vagrant /home/vagrant/.ssh

      # Enable SSH password authentication
      RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
          sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

      EXPOSE 22

      CMD ["/lib/systemd/systemd"]
    DOCKERFILE
  end

  # Network configuration
  config.vm.network "forwarded_port", guest: 22, host: 2222, host_ip: "127.0.0.1", id: "ssh", auto_correct: true

  # SSH configuration
  config.ssh.username = "vagrant"
  config.ssh.password = "vagrant"
  config.ssh.insert_key = true
  config.ssh.host = "127.0.0.1"
  config.ssh.port = 2222
end
