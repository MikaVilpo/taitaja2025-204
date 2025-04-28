// PARAMETERS

@description('Public DNS zone used for the DNS records')
param dnsZoneName string

@description('Competition name that is used in resource names')
param competitionName string

@description('Tags used for all resources')
param tags object

@description('Location for all resources')
param deplLocation string

// VARIABLES
var saLongName = 'sa${competitionName}${uniqueString(resourceGroup().id)}'
var saName = substring(saLongName, 0, 24)
var indexFile = 'index.html'
var errorFile = '404.html'

// RESOURCES

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: saName
  location: deplLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: tags
}

resource saBlobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: sa
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${competitionName}'
  location: deplLocation
  tags: tags
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: sa
  name: guid(resourceGroup().id, managedIdentity.id, contributorRoleDefinition.id, sa.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'deploymentScript-${competitionName}'
  location: deplLocation
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  dependsOn: [
    roleAssignment
  ]
  properties: {
    azPowerShellVersion: '3.0'
    scriptContent: loadTextContent('enable-static-website.ps1')
    retentionInterval: 'PT4H'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'StorageAccountName'
        value: sa.name
      }
      {
        name: 'IndexDocumentPath'
        value: indexFile
      }
      {
        name: 'IndexDocumentContents'
        value: 'Hoster website for competition: ${competitionName}'
      }
      {
        name: 'ErrorDocument404Path'
        value: errorFile
      }
      {
        name: 'ErrorDocument404Contents'
        value: 'Hoster error file for competition: ${competitionName}'
      }
    ]
  }
}

resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: dnsZoneName
  location: 'global'
  tags: tags
  properties: {
    zoneType: 'Public'
  }
}

output saWebSiteUrl string = sa.properties.primaryEndpoints.web
output dnsZoneResourceId string = dnsZone.id
