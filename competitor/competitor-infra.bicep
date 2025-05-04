// PARAMETERS
@description('Location of the resource group')
param deplLocation string = 'swedencentral'

@description('The user principal name of the user')
param userPrincipalName string

@description('Competition name')
param competitionName string

@description('The name of the root DNS zone')
param rootDnsZoneId string

@description('Tags for resources')
param tags object = {
  competitionName: competitionName
  sourceRepository: 'https://github.com/mikavilpo/taitaja2025-204'
}

@description('The index of the user')
param userIndex int

//VARIABLES
var rootDnsZoneName = split(rootDnsZoneId, '/')[8]
var rootDnsZoneResourceGroup = split(rootDnsZoneId, '/')[4]
var rootDnsSubId = split(rootDnsZoneId, '/')[2]

//RESOURCES

resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: 'k${userIndex}.${rootDnsZoneName}'
  location: 'Global'
  tags: tags
}

module nsRecords 'ns-record-to-root.bicep' = {
  name: 'ns-record-to-root'
  scope: resourceGroup(rootDnsSubId, rootDnsZoneResourceGroup)
  params: {
    ns1: dnsZone.properties.nameServers[0]
    ns2: dnsZone.properties.nameServers[1]
    ns3: dnsZone.properties.nameServers[2]
    ns4: dnsZone.properties.nameServers[3]
    rootDnsZoneId: rootDnsZoneId
    userPrincipalName: userPrincipalName
  }
}

// Create storage account for the user and container
// The storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only.
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: toLower('k${userIndex}${competitionName}sa001')
  location: deplLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: false
    minimumTlsVersion: 'TLS1_1'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
  }
  tags: tags
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  name: 'default'
  parent: storageAccount
}

// Create blob container for the user
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: 'datalake'
  parent: blobService
  properties: {
    publicAccess: 'Container'
  }
}
