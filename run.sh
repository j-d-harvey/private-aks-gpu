#!/bin/env bash

# Ensure script exits on any error
set -e

# Required parameters
RESOURCE_GROUP="rg-pvt-aks-h100"
LOCATION="eastus2"
DEPLOYMENT_NAME="aks-h100-deployment"
TEMPLATE_FILE="main.bicep"

# Optional: update these with actual values or pass via environment/CLI
PARAM_REGISTRY_NAME="gbbpvt"
PARAM_CLUSTER_NAME="pvt-aks-h100"

# Create the resource group if it doesn’t exist
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# Deploy the Bicep template (main.bicep, which uses modules)
az deployment group create \
  --template-file "$TEMPLATE_FILE" \
  --parameters \
    registryName="$PARAM_REGISTRY_NAME" \
    clusterName="$PARAM_CLUSTER_NAME" \
    resourceGroupName="$RESOURCE_GROUP"

# Done
echo "Deployment complete."

echo "Installing NVIDIA GPU Operator..."
# Install NVIDIA GPU Operator
HELM_REPO_URL="https://nvidia.github.io/gpu-operator"
HELM_INSTALL_CMD="helm install gpu-operator nvidia/gpu-operator -n gpu-operator --create-namespace --set operator.runtimeClass=nvidia-container-runtime"

az aks command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $PARAM_CLUSTER_NAME \
    --command "helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update && $HELM_INSTALL_CMD"

# Wait for the GPU Operator to be ready
CMD="kubectl get pods -n gpu-operator"
az aks command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $PARAM_CLUSTER_NAME \
    --command "$CMD"

# check for allocatable GPUs
GPU_NODE="kubectl get nodes -l accelerator=nvidia -o json"

CMD='kubectl get nodes $GPU_NODE -o jsonpath="{.status.capacity}"'
az aks command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $PARAM_CLUSTER_NAME \
    --command "$CMD"

# testing
CMD="kubectl apply -f pod-check-nvidia-smi.yaml -n default && kubectl logs nvidia-gpu-test -n default"
az aks command invoke \
    --resource-group $RESOURCE_GROUP \
    --name $PARAM_CLUSTER_NAME \
    --command "$CMD" \
    --file pod-check-nvidia-smi.yaml
