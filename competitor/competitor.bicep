targetScope = 'subscription'

// PARAMETERS
@description('The user principal name of the user')
param userPrincipalName string

@description('User objectId')
param userObjectId string

@description('User index')
param userIndex int

@description('The location of the resource group')
param deplLocation string = 'swedencentral'

@description('Competition name')
param competitionName string

@description('The name of the root DNS zone')
param rootDnsZoneId string

@description('Tags for resources')
param tags object = {
  competitionName: competitionName
  sourceRepository: 'https://github.com/mikavilpo/taitaja2025-204'
}

//VARIABLES
var userPrefix = split(userPrincipalName, '@')[0]

//RESOURCES
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${userPrefix}-${competitionName}-prod-001'
  location: deplLocation
  tags: tags
}

module competitorInfra 'competitor-infra.bicep' = {
  scope: rg
  name: 'competitor-infra'
  params: {
    competitionName: competitionName
    rootDnsZoneId: rootDnsZoneId
    userPrincipalName: userPrincipalName
    deplLocation: rg.location
    tags: tags
    userIndex: userIndex
  }
}

resource roleAssignmentOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'roleAssignment', userObjectId)
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' //Role definition id for Owner role
    )
    principalId: userObjectId
    principalType: 'User'
  }
}
