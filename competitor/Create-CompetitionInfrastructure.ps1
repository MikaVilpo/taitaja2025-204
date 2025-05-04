<#
.SYNOPSIS
    This script creates the competition infrastructure for each competitor in Azure.

.DESCRIPTION
    The script connects to Azure and sets the context to the specified subscription. 
    It then reads a CSV file containing the details of each competitor and starts creating the infrastructure for each competitor using an Azure Bicep template.

.PARAMETER csvPath
    The path to the CSV file containing the details of each competitor.

.PARAMETER deploymentLocation
    The Azure location where the infrastructure will be deployed. Defaults to 'swedencentral'.

.PARAMETER competitionName
    The name of the competition.

.PARAMETER rootDnsZoneId
    The ID of the root DNS zone in Azure.

.PARAMETER targetSubscriptionId
    The ID of the Azure subscription where the infrastructure will be deployed.

.EXAMPLE
    .\Create-CompetitionInfrastructure.ps1 -csvPath "competitors.csv" -competitionName "CodeChallenge" -rootDnsZoneId "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-taitaja2024-hoster-prod-001/providers/Microsoft.Network/dnszones/example.com" 

.NOTES
    The script requires the 'Microsoft.Azure.PowerShell.Cmdlets.ResourceManager' module and the 'Az.Accounts' module.
    The script uses the 'Connect-AzAccount' and 'Set-AzContext' cmdlets to connect to Azure and set the context to the specified subscription.
    The script uses the 'New-AzDeployment' cmdlet to create the infrastructure for each competitor.
#>
# Input parameters 
param (
    [Parameter(Mandatory = $true)]
    [string]$csvPath,
    [Parameter(Mandatory = $false)]
    [string]$deploymentLocation = 'swedencentral',
    [Parameter(Mandatory = $true)]
    [string]$competitionName,
    [Parameter(Mandatory = $true)]
    [string]$rootDnsZoneId
)

# Connect to Azure for deployment
try {
    Connect-AzAccount
}
catch {
    throw 'Login failed.'
}

# Get CSV Data for all the competitor user accounts
$competitorUserAccounts = Import-Csv -Path $csvPath -Encoding utf8

# Start creating the infrastructure for each competitor
$userIndex=1

try {
    foreach($competitor in $competitorUserAccounts) {
        try {
            # Create the infrastructure for each competitor using the Bicep template
            Write-Host "Creating infrastructure for competitor $($competitor.UserPrincipalName) with user index $userIndex"
            Set-AzContext -SubscriptionId $competitor.subscriptionId -ErrorAction Stop

            New-AzDeployment -Location $deploymentLocation -TemplateFile ".\competitor.bicep" -UserPrincipalName $competitor.UserPrincipalName -userObjectId $competitor.ObjectId -competitionName $competitionName -rootDnsZoneId $rootDnsZoneId -deplLocation $deploymentLocation -userIndex $userIndex
            $userIndex++
        }
        catch {
            throw "Could not create infrastructure for competitor $($competitor.UserPrincipalName). $($_.Exception)"
        }
    }
}
catch {
    throw "Failed to create infrastructure for the competitors. $($_.Exception)"
}