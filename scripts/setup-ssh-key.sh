#!/usr/bin/env bash
# Add SSH public key to server
PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC2D/DyBI/hcq2xz31xcwnkFQxJaGZbCMrQL8JLORbcJ admin@root"

mkdir -p ~/.ssh
echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

echo "✓ Public key added to ~/.ssh/authorized_keys"
