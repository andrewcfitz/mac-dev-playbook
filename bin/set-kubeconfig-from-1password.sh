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
CONTEXT=$(echo "$HOSTNAME" | awk -F. '{OFS="."; NF-=2; print}')
OP_ITEM_NAME="k3s config - ${HOSTNAME}"    # Construct the 1Password item name
KUBE_CONFIG_FIELD="config"                 # The field name containing the kubeconfig value
KUBE_CONFIG_DIR="$HOME/.kube"              # Directory to save the kubeconfig file
KUBE_CONFIG_PATH="$KUBE_CONFIG_DIR/config" # Full path to the kubeconfig file
KUBE_CLUSTER_CONFIG_PATH="$KUBE_CONFIG_DIR/config-${CONTEXT}" # Full path to the cluster kubeconfig file

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

# Remove surrounding quotes from the kubeconfig content, if any
KUBECONFIG_CONTENT=$(echo "$KUBECONFIG_CONTENT" | sed 's/^"//;s/"$//')

# Check if the kubeconfig value was fetched successfully
if [ -z "$KUBECONFIG_CONTENT" ]; then
  echo "Error: Could not retrieve kubeconfig from 1Password. Check item name and field."
  exit 1
fi

# Ensure the .kube directory exists
if [ ! -d "$KUBE_CONFIG_DIR" ]; then
  echo "Creating .kube directory at $KUBE_CONFIG_DIR"
  mkdir -p "$KUBE_CONFIG_DIR"
fi

# Save the kubeconfig content to the kubeconfig file
echo "$KUBECONFIG_CONTENT" > "$KUBE_CLUSTER_CONFIG_PATH"
echo "Kubeconfig saved to $KUBE_CLUSTER_CONFIG_PATH"

# Optionally remove the context using kubecm if the kubeconfig file exists
if [ -f "$KUBE_CONFIG_PATH" ]; then
  if command -v kubecm &> /dev/null; then
    echo "Removing context $CONTEXT from kubeconfig"
    kubecm delete $CONTEXT || echo "Warning: Failed to remove context $CONTEXT"
  else
    echo "Warning: kubecm is not installed. Skipping context removal."
  fi
else
  echo "Warning: Kubeconfig file does not exist. Skipping context removal."
  touch "$KUBE_CONFIG_PATH"
fi

# Add the context to the config file
kubecm add -cf $KUBE_CLUSTER_CONFIG_PATH --context-name $CONTEXT

# Set the current context using kubectl
echo "Setting current context to $CONTEXT"
kubectl config use-context "$CONTEXT" --kubeconfig="$KUBE_CONFIG_PATH"