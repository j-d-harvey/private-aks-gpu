# Pattern – Deploying a Private AKS H100 GPU Cluster with Bicep

This is a fork from https://github.com/appdevgbb/pattern-private-aks-gpu

This repository automates the deployment of a **private Azure Kubernetes Service (AKS)** cluster with **NVIDIA H100 GPUs**, using **Bicep** and **Helm**. It also installs the **NVIDIA GPU Operator** for GPU workload support.

---

## Features

- Deploys a private AKS cluster using Bicep (`main.bicep`)
- Sets up an Azure Container Registry (ACR)
- Installs the NVIDIA GPU Operator using Helm
- Verifies GPU access with a test pod running `nvidia-smi`

---

## Prerequisites

Make sure the following tools are installed:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [Helm](https://helm.sh/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [GitHub CLI (optional)](https://cli.github.com/)

---

## Usage

### Step 1: Run the Deployment Script

```bash
chmod +x run.sh
./run.sh
```

Update the variables inside `run.sh` to match your environment:

```bash
RESOURCE_GROUP="rg-pvt-aks-h100"
LOCATION="eastus2"
PARAM_REGISTRY_NAME="gbbpvt"
PARAM_CLUSTER_NAME="pvt-aks-h100"
```

---

## Repository Structure

- `main.bicep` – Main Bicep template for deploying infrastructure
- `run.sh` – Script to deploy AKS and install GPU Operator
- `pod-check-nvidia-smi.yml` – Pod spec to verify GPU access

### GitHub Actions Workflows

| Step | File | Description |
|------|------|-------------|
| 1 | `.github/workflows/deploy.yml` | Deploy infrastructure |
| 2 | `.github/workflows/attach-aks-to-acr.yml` | Attach AKS to ACR using managed identity |
| 3 | `.github/workflows/nvidia-gpu-operator.yml` | Install NVIDIA GPU Operator |
| 4 | `.github/workflows/test.yml` | Run GPU test using `nvidia-smi` |
| 9999 | `.github/workflows/delete-resources.yml` | Delete deployed resources |

---

## GitHub Actions Integration

### Step 1: Fork the Repository

Fork this repo to your GitHub account.

### Step 2: Create a User-Assigned Managed Identity

```bash
MI_NAME="github-actions-identity"
RESOURCE_GROUP_MI="rg-github-actions-identity"
LOCATION="eastus2"
REGISTRY_NAME="gbbpvt"

az group create --name "$RESOURCE_GROUP_MI" --location "$LOCATION"

az identity create \
  --name "$MI_NAME" \
  --resource-group "$RESOURCE_GROUP_MI" \
  --location "$LOCATION"

RESOURCE_GROUP="rg-pvt-aks-h100"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
```

### Step 3: Save Identity Info

```bash
CLIENT_ID=$(az identity show -g "$RESOURCE_GROUP_MI" -n "$MI_NAME" --query clientId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
```

### Step 4: Assign Role

```bash
MI_PRINCIPAL_ID=$(az identity show -g "$RESOURCE_GROUP_MI" -n "$MI_NAME" --query principalId -o tsv)

az role assignment create \
  --assignee-object-id "$MI_PRINCIPAL_ID" \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP
```

### Step 5: Create Federated Identity Credential

```bash
GITHUB_ORG="appdevgbb"
REPO="pattern-private-aks-gpu"

az identity federated-credential create \
  --name github-actions \
  --identity-name "$MI_NAME" \
  --resource-group "$RESOURCE_GROUP_MI" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:$GITHUB_ORG/$REPO:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"
```

### Step 6: Create GitHub Secrets

Go to your GitHub repo:

**Settings → Secrets and variables → Actions → New repository secret**

Create these secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Use the values from Step 3.

---

## Attach AKS to ACR

After deployment, grant the GitHub Actions identity permission to assign roles to the AKS kubelet:

```bash
ACR_ID=$(az acr show -n "$REGISTRY_NAME" -g "$RESOURCE_GROUP" --query id -o tsv)

az role assignment create \
  --assignee-object-id "$MI_PRINCIPAL_ID" \
  --role "User Access Administrator" \
  --scope "$ACR_ID"
```

Then run the workflow:

```text
.github/workflows/attach-aks-to-acr.yml
```

---

## Validation

Once everything is deployed:

- Check GPU readiness by applying `pod-check-nvidia-smi.yml`
- Use `kubectl logs` to verify the output of `nvidia-smi`

---

## Cleanup

To clean up resources:

```bash
gh workflow run delete-resources.yml
```

Or manually delete them using the Azure CLI or portal.

---

## License

MIT License. See [LICENSE](LICENSE) for details.