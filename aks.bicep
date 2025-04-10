param clusterName string
param managedClusterName string = clusterName
param subnetExternalId string
param location string
param registryName string
param gpuSKU string

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${managedClusterName}-log'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      legacy: 0
    }
  }
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2025-01-01' = {
  name: managedClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.30.10'
    dnsPrefix: '${managedClusterName}-dns'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 2
        vmSize: 'Standard_D4ds_v5'
        vnetSubnetID: subnetExternalId
        osDiskSizeGB: 150
        osDiskType: 'Ephemeral'
        kubeletDiskType: 'OS'
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        maxCount: 5
        minCount: 2
        enableAutoScaling: true
        orchestratorVersion: '1.30.10'
        enableNodePublicIP: false
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        upgradeSettings: {
          maxSurge: '10%'
        }
        enableFIPS: false
        securityProfile: {
          enableVTPM: false
          enableSecureBoot: false
        }
      }
      {
        name: 'gpunp'
        count: 1
        vmSize: gpuSKU
        vnetSubnetID: subnetExternalId
        osDiskSizeGB: 322
        osDiskType: 'Ephemeral'
        kubeletDiskType: 'OS'
        maxPods: 30
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '2'
        ]
        enableAutoScaling: false
        orchestratorVersion: '1.30.10'
        gpuProfile: {
          driver: 'None'
        }

        enableNodePublicIP: false
        mode: 'User'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        upgradeSettings: {
          maxSurge: '10%'
        }
        enableFIPS: false
        securityProfile: {
          enableVTPM: false
          enableSecureBoot: false
        }
      }
     ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspace.id
          useAADAuth: 'true'
        }
      }
    }
    enableRBAC: true
    supportPlan: 'KubernetesOfficial'
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'cilium'
      networkDataplane: 'cilium'
      loadBalancerSku: 'Standard'
      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      outboundType: 'loadBalancer'
      podCidrs: [ '10.244.0.0/16' ]
      serviceCidrs: [ '10.0.0.0/16' ]
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system'
      enablePrivateClusterPublicFQDN: true
    }
    autoUpgradeProfile: {
      upgradeChannel: 'none'
      nodeOSUpgradeChannel: 'SecurityPatch'
    }
    disableLocalAccounts: false
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 168
      }
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${managedClusterName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetExternalId
    }
    privateLinkServiceConnections: [
      {
        name: 'kube-apiserver-connection'
        properties: {
          privateLinkServiceId: managedCluster.id
          groupIds: [ 'management' ]
        }
      }
    ]
  }
}

resource registry 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
      softDeletePolicy: {
        retentionDays: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
    metadataSearch: 'Disabled'
  }
}

output kubeletPrincipalId string = managedCluster.properties.identityProfile.kubeletidentity.objectId
output registryId string = registry.id
