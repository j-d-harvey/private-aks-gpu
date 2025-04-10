param registryName string
param clusterName string
param managedClusterName string = clusterName
param resourceGroupName string = 'rg-${managedClusterName}'
param location string = 'usgovarizona'
param gpuVMSKU string = 'SStandard_ND96isr_H100_v5 VMs'

module infra 'aks.bicep' = {
  name: 'provisionInfra'
  scope: resourceGroup(resourceGroupName)
  params: {
    clusterName: managedClusterName
    location: location
    registryName: registryName
    gpuSKU: gpuVMSKU
    subnetExternalId: '<replace-with-subnet-id>'
  }
}
