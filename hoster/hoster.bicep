targetScope = 'subscription'

// PARAMETERS

@description('Public DNS zone used for the DNS records')
param dnsZoneName string

@description('Competition name that is used in resource names')
param competitionName string

@description('Deployment region')
param deplLocation string = 'swedencentral'

@description('Tags used for all resources')
param tags object = {
  competitionName: competitionName
  sourceRepository: 'https://github.com/mmaraa/taitaja2024'
}

// VARIABLES

var rgName = 'rg-${competitionName}-hoster-prod-001'

// RESOURCE DEFINITIONS

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  tags: tags
  location: deplLocation
}

module infra 'hoster_infra.bicep' = {
  name: 'infra'
  params: {
    dnsZoneName: dnsZoneName
    competitionName: competitionName
    tags: tags
    deplLocation: deplLocation
  }
  scope: rg
}

output websiteUrl string = infra.outputs.saWebSiteUrl
output dnsZoneResourceId string = infra.outputs.dnsZoneResourceId
