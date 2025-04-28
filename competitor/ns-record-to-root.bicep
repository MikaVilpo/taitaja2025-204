// PARAMETERS
@description('The user principal name of the user')
param userPrincipalName string

@description('The name of the root DNS zone')
param rootDnsZoneId string

@description('Child NS1')
param ns1 string

@description('Child NS2')
param ns2 string

@description('Child NS3')
param ns3 string

@description('Child NS4')
param ns4 string

//VARIABLES
var userPrefix = split(userPrincipalName, '@')[0]
var userIndex = split(userPrefix, '-')[1]
var rootDnsZoneName = split(rootDnsZoneId, '/')[8]


// RESOURCES

resource rootDnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' existing = {
  name: rootDnsZoneName
}

resource nsRecords 'Microsoft.Network/dnsZones/NS@2023-07-01-preview' = {
  name: userIndex
  parent: rootDnsZone
  properties: {
    TTL: 3600
    NSRecords: [
      {
        nsdname: ns1
      }
      {
        nsdname: ns2
      }
      {
        nsdname: ns3
      }
      {
        nsdname: ns4
      }
    ]
  }
}
