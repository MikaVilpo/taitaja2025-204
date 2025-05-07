<#
.SYNOPSIS
This script checks various criteria for competitors in a Taitaja competition.

.DESCRIPTION
The script checks different aspects of competitors' configurations, such as SFTP service, web page, automation, and Azure monitoring.

.PARAMETER csvPath
The path to the CSV file containing competitor information. Default value is '.\competitors.csv'.

.NOTES
Author: Mika Vilpo
Date: 2025-05-07

.EXAMPLE
.\Check-Competitors.ps1 -csvPath '.\competitors.csv'
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $csvPath = '.\competitors.csv'
)

# Requires Posh-SSH module
# Requires Az module
# Resuires Az.ConnectedMachine module

# CSV Schema
# name,number,subscriptionid,sftpaccount,sftppassword

$competitors = Import-Csv $csvPath

# Debugging
# $competitor = $competitors[1]

# check that we are connected to azure
if (-not (Get-AzContext)) {
    Connect-AzAccount
}


foreach ($competitor in $competitors) {
    # switch to correct subscription
    $null = Set-AzContext -SubscriptionId $competitor.subscriptionId -WarningAction SilentlyContinue

    # D1 SFTP-palvelu

    # D1.1 SFTP-palvelu enabloitu storage accountista - Storage account vastaa SFTP-palveluun
    $SFTPAccount = $null
    if ($competitor.sftpAccount) {
        $SFTPAccount = Get-AzStorageAccount -StorageAccountName $($competitor.sftpAccount) -ErrorAction SilentlyContinue | Select-Object StorageAccountName, ResourceGroupName, EnableSftp
    }
    if ($SFTPAccount.EnableSftp) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): D1.1 - 1 - SFTP is enabled"

        # D1.2 Tunnus luotu	- Tunnus löytyy konfiguraatiosta
        $SFTPUser = $null
        if ($competitor.sftpAccount) {
            $SFTPUser = Get-AzStorageLocalUser -StorageAccountName $($competitor).sftpAccount -ErrorAction SilentlyContinue | Select-Object Name, HasSshPassword
        }

        if ($SFTPUser.Name -eq 'sftpintegpalkkalaskenta' -and $SFTPUser.HasSshPassword) {
            Write-Host -BackgroundColor Green "$($Competitor.Name): D1.2 - 1 - SFTP user sftpintegpalkkalaskenta created and has SSH password"

            # B1.3 Tunnus toimii - Tunnuksella pääsee kirjautumaan SFTP-palveluun
            $SFTPSession = $null
            $ConnectionEndpoint = $null
            if ($competitor.sftpAccount -and $competitor.sftpPassword) {
                [pscredential]$SFTPCredential = New-Object System.Management.Automation.PSCredential ("$($competitor.sftpAccount).sftppalkat.sftpintegpalkkalaskenta", $(ConvertTo-SecureString $($competitor.sftpPassword) -AsPlainText -Force) )
                $ConnectionEndpoint = "$($competitor.sftpAccount).blob.core.windows.net"
                $SFTPSession = New-SFTPSession -Credential $SFTPCredential -HostName $ConnectionEndpoint -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }

            if ($SFTPSession) {
                Write-Host -BackgroundColor Green "$($Competitor.Name): D1.3 - 1 - SFTP connection to $ConnectionEndpoint successful"
                $null = Remove-SFTPSession $SFTPSession
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): D1.3 - 0 - SFTP connection to $ConnectionEndpoint failed"
            }
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): D1.2 - 0 - SFTP user sftpintegpalkkalaskenta not found or does not have SSH password"
            Write-Host -BackgroundColor Red "$($Competitor.Name): D1.3 - 0 - SFTP user sftpintegpalkkalaskenta not found or does not have SSH password"
        }
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): D1.1 - 0 - SFTP is not enabled"
        Write-Host -BackgroundColor Red "$($Competitor.Name): D1.2 - 0 - SFTP is not enabled"
        Write-Host -BackgroundColor Red "$($Competitor.Name): D1.3 - 0 - SFTP is not enabled"
    }

    # B2 Web-sivu

    $DNSName = "www.k$($competitor.number).taitaja.online"
    $DNSEntry = Resolve-DnsName $DNSName -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq 'CNAME' }
    if ($DNSEntry) {
        $StorageAccountName = $dnsentry[0].namehost.split('.')[0]
        $StorageAccount = Get-AzStorageAccount -Name $StorageAccountName -ErrorAction SilentlyContinue  

        if ($StorageAccount) {
            # B2.1 Staattinen web-sivu otettu käyttöön - Storage accountista enabloitu static web page

            $StorageProperties = Get-AzStorageServiceProperty -ServiceType blob -Context $StorageAccount.Context -ErrorAction SilentlyContinue 

            if ($StorageProperties.StaticWebsite.Enabled) {
                Write-Host -BackgroundColor Green "$($Competitor.Name): D2.1 - 1 - DNS entry $DNSName points to storage account $StorageAccountName and has static website enabled."
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): D2.1 - 0 - DNS entry $DNSName points to storage account $StorageAccountName but static website is not enabled."
            }
            # B2.2 Web-sivu aukeaa selaimella - Annettu index.html-sivu aukeaa

            $Website = $null
            $Website = Invoke-WebRequest -Uri "http://$($DNSName)" -ErrorAction SilentlyContinue
            if ($Website.Content -like '*<title>taitaja.online</title>*') {
                Write-Host -BackgroundColor Green "$($Competitor.Name): D2.2 - 1 - Website $DNSName is reachable and displays maintenance page."
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): D2.2 - 0 - Website $DNSName is not reachable or does not display maintenance page."
            }
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): D2.1 - 0 - DNS entry $DNSName does not point to a storage account"
            Write-Host -BackgroundColor Red "$($Competitor.Name): D2.2 - 0 - DNS entry $DNSName does not point to a storage account"
        }
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): D2.1 - 0 - DNS entry $DNSName not found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): D2.2 - 0 - DNS entry $DNSName not found"
    }

    # B3 Automatisoinnin modernisointi

    # B3.1 Kone yhdistetty Azureen - Arc-objekti löytyy connected-tilassa

    $ArcMachine = Get-AzConnectedMachine -SubscriptionId $($competitor.subscriptionid) -ErrorAction SilentlyContinue

    if ($ArcMachine.Status -eq 'Connected') {
        Write-Host -BackgroundColor Green "$($Competitor.Name): D3.1 - 1 - Azure Arc machine $($ArcMachine.Name) is connected"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): D3.1 - 0 - Azure Arc machine not connected"
    }

    # B4 Azure valvonta

    # B4.2 VM Insights otettu käyttöön pyydetysti VM Insights perf ja dependency arcatulla koneella
    $ArcExtensions = $null
    if ($ArcMachine) {
        $ArcExtensions = Get-AzConnectedMachineExtension -MachineName $ArcMachine.Name -ResourceGroupName $ArcMachine.ResourceGroupName -ErrorAction SilentlyContinue
    }
    if ($ArcExtensions.Name -contains 'AzureMonitorWindowsAgent' -and $ArcExtensions.Name -contains 'DependencyAgentWindows') {
        Write-Host -BackgroundColor Yellow "$($Competitor.Name): D4.2 -   - 1 point - Dependency Agent extension is installed on Azure Arc machine $($ArcMachine.Name). CHECK FUNCTIONALITY!"
    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): D4.2 - 0 - No Dependency Agent extension found"
    }

    # D4.3 MANUAL
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D4.3 -   - 1 point - CHECK UPDATE SCHEDULE"

    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D4.4 -   - 1 point - CHECK CHANGE TRACKING"


    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D5.1 -   - 0,5 point - Public access poistettu, SAS-estetty"
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D5.2 -   - 0,5 point - HTTPS pakotettu päälle ja uusin TLS versio"
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D5.3 -   - 1 point - Kaikki pyydetyt plänit on enabloitu"
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D5.4 -   - 1 point - Näkyy ok onboardattuna security.microsoft.com"
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): D5.5 -   - 1 point - Tiedoston metadatassa näkyy, että se on skannattu"


    # B6 Tekoäly				
    # B6.1 Open AI Service asennettu - Palvelu asennettu ja hubi luotu
    $AIServices = Get-AzResource -ResourceType 'microsoft.cognitiveservices/accounts'
    $AIHubs = Get-AzResource -ResourceType 'Microsoft.MachineLearningServices/workspaces'

    if ($AIServices -and $AIHubs) {
        Write-Host -BackgroundColor Green "$($Competitor.Name): B6.1 - 1 - AI Service and AI Hub are present"
    
        # B6.2 Mallit asennettu käytettäväksi - GPT ja Text embedding malli deployattu
        $deployments = @()
        foreach ($AIService in $AIServices) {
            $AIDeploymentsUri = $AIService.ResourceId + '/deployments?api-version=2023-05-01'
            $deployments = ((Invoke-AzRestMethod -Path $AIDeploymentsUri -Method GET).Content | ConvertFrom-Json).value
        }
        $b62Points = 0
        foreach ($deployment in $deployments) {
            if ($deployment.properties.model.name -eq 'gpt-4' -or $deployment.properties.model.name -eq 'text-embedding-ada-002') {
                $b62Points += 0.5
            }
        }

        if ($b62Points -gt 1) { $b62Points = 1 }

        if ($b62Points -eq 0) {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.2 - 0 - No models deployed"
        }
        else {    
            Write-Host -BackgroundColor Green "$($Competitor.Name): B6.2 - $b62Points - Models deployed"
        }

        # B6.3 AI Search deplyattu - AI Search löytyy
        $AISearch = Get-AzResource -ResourceType 'Microsoft.Search/searchServices'
        if ($AISearch) {
            Write-Host -BackgroundColor Green "$($Competitor.Name): B6.3 - 1 - AI Search is present"

            # B6.4 Search Index luotu oikeasta datasta - Index luotu oikeasta datasta
            Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.4 -   - 2 points - CHECK SEARCH INDEX FOR CORRECT DATA!"

            # B6.5 Custom data käytettävissä playgroundissa - Index lisätty AI Projektiin siten, että toimii playgroundissa
            Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.5 -   - 2 points - CHECK CUSTOM DATA IN PLAYGROUND!"        
        }
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.3 - 0 - No AI Search found"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.4 - 0 - No AI Search found"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.5 - 0 - No AI Search found"
        }

        # B6.6 Selainpohjainen chat-applikaatio käytettävissä - Chat applikaatioon pääsee sisälle
        $WebApp = Get-AzWebApp -SubscriptionId $($competitor.subscriptionid) -ErrorAction SilentlyContinue
        if ($WebApp) {
            $WebRequest = Invoke-WebRequest -Uri "https://$($WebApp.DefaultHostName)" -TimeoutSec 15 -ErrorAction SilentlyContinue
        }
        else {
            $WebRequest = $null
        }
        If ($WebRequest.content -like '*<div id="root"></div>*') {
            Write-Host -BackgroundColor Green "$($Competitor.Name): B6.6 - 1 - WebApp is present and anonymous login allowed at: https://$($WebApp.DefaultHostName)"
            # B6.7 Selainpohjainen chat-applikaatio vastaa omasta datasta - Kysyttäessä taitaja-kilpailuiden ylintä päätösvaltaa käyttävää elintä saadaan vastaukseksi jury.
            if ($AISearch) {
                Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.7 -   - 2 points - Ask: 'Mikä on Taitaja kilpailuiden ylintä päätösvaltaa käyttävä elin?' and check the answer!"
                # B6.8 Selainpohjainen chat-applikaatio vastaa oikein tuntemattomaan dataan - Kysyttäessä taitaja-kilpailuiden pääjohtajan puhelinnumeroa saadaan vastauksesi, ettei sitä löydetä
                Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.8 -   - 1 point - Ask: 'Mikä on Taitaja kilpailuiden pääjohtajan puhelinnumero?' and check the answer!"
            }
            else {
                Write-Host -BackgroundColor Red "$($Competitor.Name): B6.7 - 0 - No AI Search found"
                Write-Host -BackgroundColor Red "$($Competitor.Name): B6.8 - 0 - No AI Search found"
            }
        }            
        else {
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.6 - 0 - No Website deployed"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.7 - 0 - No Website deployed"
            Write-Host -BackgroundColor Red "$($Competitor.Name): B6.8 - 0 - No Website deployed"
        }

    }
    else {
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.1 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.2 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.3 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.4 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.5 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.6 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.7 - 0 - No AI services or AI hubs found"
        Write-Host -BackgroundColor Red "$($Competitor.Name): B6.8 - 0 - No AI services or AI hubs found"
    }
    
    # B6.9 Villelle toimitettu yksinkertainen PDF ohjeistus - Sähköpostista löytyy yksinkertainen PDF-ohjeistus
    Write-Host -BackgroundColor Yellow "$($Competitor.Name): B6.9 -   - 1 point - CHECK EMAIL FOR PDF INSTRUCTIONS!"

}   