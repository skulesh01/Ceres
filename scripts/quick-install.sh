#!/bin/bash
# Very simple k3s installation script

echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -

echo ""
echo "Waiting for k3s to start..."
sleep 30

echo ""
echo "Checking installation..."
k3s --version
kubectl get nodes

echo ""
echo "Done!"
