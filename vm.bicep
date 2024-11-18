@description('The name of the resource group.')
param resourceGroupName string

@description('The location for the resources.')
param location string

@description('The size of the VMs.')
param vmSize string

@description('The base name for the VMs. Each VM will use this name as a prefix.')
param vmBaseName string

@description('The number of VMs to create.')
param vmCount int

@secure()
@description('The admin username for the VMs.')
param adminUsername string

@secure()
@description('The admin password for the VMs.')
param adminPassword string

@description('The URL of the PowerShell script to execute on the VMs.')
param scriptUri string

@description('The command to execute the PowerShell script.')
param commandToExecute string

// Virtual Network Definition with additional subnets
resource vnet1 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vnet1'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet' // Required subnet for Azure Bastion
        properties: {
          addressPrefix: '10.0.3.0/26'
        }
      }
    ]
  }
}

// Network Security Group with RDP, SSH, and WinRM (HTTP & HTTPS) Rules
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: 'nsg'
  location: location
  properties: {
    securityRules: [
      // Existing RDP Rule
      {
        name: 'Allow-RDP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      // New SSH Rule
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1010  // Higher priority than RDP
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'  // SSH port
          sourceAddressPrefix: '*'  // Any source IP
          destinationAddressPrefix: '*'  // Apply to all VMs
        }
      }
      // New WinRM HTTP Rule (Port 5985)
      {
        name: 'Allow-WinRM-HTTP'
        properties: {
          priority: 1020  // Higher priority than SSH and RDP
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'  // Allow traffic from any source port
          destinationPortRange: '5985'  // WinRM HTTP port
          sourceAddressPrefix: '*'  // Allow from any IP (you can restrict this if needed)
          destinationAddressPrefix: '*'  // Apply to all VMs
        }
      }
      // New WinRM HTTPS Rule (Port 5986)
      {
        name: 'Allow-WinRM-HTTPS'
        properties: {
          priority: 1030  // Higher priority than HTTP rule
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'  // Allow traffic from any source port
          destinationPortRange: '5986'  // WinRM HTTPS port
          sourceAddressPrefix: '*'  // Allow from any IP (you can restrict this if needed)
          destinationAddressPrefix: '*'  // Apply to all VMs
        }
      }
    ]
  }
}


// Loop to create NICs with NSG attached
resource nics 'Microsoft.Network/networkInterfaces@2021-02-01' = [for i in range(0, vmCount): {
  name: '${vmBaseName}${i + 1}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig${i + 1}'
        properties: {
          subnet: {
            id: '${vnet1.id}/subnets/subnet1'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}]

// Loop to create VMs
resource vms 'Microsoft.Compute/virtualMachines@2021-03-01' = [for i in range(0, vmCount): {
  name: '${vmBaseName}${i + 1}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmBaseName}${i + 1}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-10'
        sku: 'win10-21h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

// Loop to create Custom Script Extensions for each VM
resource customScriptExtensions 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = [for i in range(0, vmCount): {
  name: '${vms[i].name}/CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        scriptUri
      ]
      commandToExecute: commandToExecute
    }
  }
  dependsOn: [
    vms[i]
  ]
}]

// Azure Bastion Resource
resource bastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: 'bastionHost'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIPConfig'
        properties: {
          subnet: {
            id: '${vnet1.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
 
}

// Public IP Address for Azure Bastion
resource bastionPip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'bastionPip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}




