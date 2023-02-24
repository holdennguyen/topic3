#!/bin/bash

# Add user ansible admin
useradd ansibleadmin 

# Set password: the below command will avoid re-entering the password
echo "ansibleadmin" | passwd --stdin ansibleadmin

# Modify the sudoers file at /etc/sudoers and add entry
echo 'ansibleadmin  ALL=(ALL)   NOPASSWD: ALL' | tee -a /etc/sudoers
echo 'ec2-user ALL=(ALL) NOPASSWD: ALL' | tee -a /etc/sudoers

# Enable Password Authentication
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd