#!/bin/bash

# Exit on errors
set -e

# Check if the hostname parameter is provided
if [ -z "$1" ]; then
  echo "Usage: kubecfg1p <hostname>"
  exit 1
fi

# Variables
HOSTNAME="$1"
OP_ITEM_NAME="k3s config - ${HOSTNAME}"    # Construct the 1Password item name
KUBE_CONFIG_FIELD="kubeconfig"             # The field name containing the kubeconfig value
KUBE_CONFIG_PATH="$HOME/.kube/config"      # Path to save the kubeconfig file

# Check if the 1Password CLI is installed
if ! command -v op &> /dev/null; then
  echo "Error: 1Password CLI ('op') is not installed. Please install it first."
  exit 1
fi

# Sign in to 1Password if not already signed in
if ! op whoami &> /dev/null; then
  echo "Signing in to 1Password CLI..."
  eval $(op signin)
fi

# Fetch the kubeconfig value from 1Password
echo "Fetching kubeconfig from 1Password item: $OP_ITEM_NAME, field: $KUBE_CONFIG_FIELD"
KUBECONFIG_CONTENT=$(op item get "$OP_ITEM_NAME" --field "$KUBE_CONFIG_FIELD")

# Check if the kubeconfig value was fetched successfully
if [ -z "$KUBECONFIG_CONTENT" ]; then
  echo "Error: Could not retrieve kubeconfig from 1Password. Check item name and field."
  exit 1
fi

# Backup the existing kubeconfig if it exists
if [ -f "$KUBE_CONFIG_PATH" ]; then
  echo "Backing up existing kubeconfig to ${KUBE_CONFIG_PATH}.bak"
  cp "$KUBE_CONFIG_PATH" "${KUBE_CONFIG_PATH}.bak"
fi

# Write the kubeconfig to the file
echo "Writing kubeconfig to $KUBE_CONFIG_PATH"
echo "$KUBECONFIG_CONTENT" > "$KUBE_CONFIG_PATH"

# Set KUBECONFIG environment variable (optional)
export KUBECONFIG="$KUBE_CONFIG_PATH"
echo "KUBECONFIG is set to $KUBE_CONFIG_PATH"

# Test kubectl connectivity (optional)
if command -v kubectl &> /dev/null; then
  echo "Testing Kubernetes connectivity..."
  kubectl cluster-info
else
  echo "kubectl not found. Install kubectl to test connectivity."
fi

echo "Kubeconfig has been successfully set!"