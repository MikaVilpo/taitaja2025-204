<#
.SYNOPSIS
    This script creates user accounts for competitors in a Microsoft 365 tenant.

.DESCRIPTION
    The script connects to a Microsoft 365 tenant using the Microsoft Graph API and creates a specified number of user accounts for competitors. 
    It generates a random password for each user and sets the user's properties such as UserPrincipalName, DisplayName, GivenName, and MailNickname. 
    The script also creates a CSV file that contains the UserPrincipalName, ObjectId, and Password for each created user.

.PARAMETER countOfCompetitors
    The number of competitor user accounts to create.

.PARAMETER tenantDomainName
    The domain name of the Microsoft 365 tenant where the user accounts will be created.

.EXAMPLE
    .\Create-CompetitorUserAccounts.ps1 -countOfCompetitors 10 -tenantDomainName "example.com"

.NOTES
    The script requires the 'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.AccessAsUser.All', and 'PrivilegedAccess.ReadWrite.AzureADGroup' permissions in Microsoft Graph.
    The script uses the Microsoft Graph PowerShell SDK to interact with Microsoft 365.
#>

#Input parameters 
param (
    [Parameter(Mandatory = $true)]
    [int]$countOfCompetitors,
    [Parameter(Mandatory = $true)]
    [string]$tenantDomainName
)

# Connect to the Microsoft 365 tenant and create user accounts for the competitors.

try {
    Connect-MgGraph `
        -Scopes 'User.ReadWrite.All', 'UserAuthenticationMethod.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.AccessAsUser.All', 'PrivilegedAccess.ReadWrite.AzureADGroup' `
        -ContextScope Process 

}
catch {
    throw 'Login failed.'
}

# Create CSV for all the competitor user accounts.
$csvPath = 'competitorUserAccounts.csv'
$csvHeader = 'UserPrincipalName,ObjectId,Password,TemporaryAccessPass,subscriptionId'
$csvHeader | Out-File -FilePath $csvPath -Encoding utf8
# Create user accounts for the competitors.
try {
    foreach ($i in 1..$countOfCompetitors) {
        try {

            $createdUser = $null

            $pass = -join ((45..122) | Get-Random -Count 12 | ForEach-Object { [char]$_ })
            

            $PasswordProfile = @{
                Password                      = $pass
                ForceChangePasswordNextSignIn = $false
            }

            Write-Output "Creating user account: competitor-k$i@$TenantDomainName"

            $user = New-MgUser `
                -UserPrincipalName "competitor-k$i@$TenantDomainName" `
                -DisplayName "Competitor k$i" `
                -GivenName "Competitor k$i" `
                -PasswordProfile $PasswordProfile `
                -MailNickname "competitork$i" `
                -AccountEnabled
      
            # Check that user was created successfully
            $createdUser = Get-MgUser -UserId $user.Id -ErrorAction SilentlyContinue

            while ($null -eq $createdUser) {
                Write-Output 'Waiting for user account creation to complete...'
                Start-Sleep -Seconds 5
                $createdUser = Get-MgUser -UserId $user.Id -ErrorAction SilentlyContinue
            }

            # Create Temporary Access Pass for the user
            Write-Output "Creating Temporary Access Pass for user: $($user.UserPrincipalName)"

            $temporaryAccessPass = New-MgUserAuthenticationTemporaryAccessPassMethod `
                -UserId $user.Id `
                -LifetimeInMinutes 14400 `
                -ErrorAction SilentlyContinue

            while ($null -eq $temporaryAccessPass) {
                Write-Output 'Waiting for Temporary Access Pass creation to complete...'
                Start-Sleep -Seconds 5
                $temporaryAccessPass = New-MgUserAuthenticationTemporaryAccessPassMethod `
                    -UserId $user.Id `
                    -LifetimeInMinutes 14400 `
                    -ErrorAction SilentlyContinue   
            }

            $csvUser = "$($user.UserPrincipalName),$($user.Id),$pass,$($temporaryAccessPass.temporaryAccessPass)"
            $csvUser | Out-File -FilePath $csvPath -Encoding utf8 -Append

        }
        catch {
            throw "Failed to create user account: competitor-k$i."
        }
        
    }

}

catch {
    throw "Failed to create user accounts. $($_.Exception)"
}