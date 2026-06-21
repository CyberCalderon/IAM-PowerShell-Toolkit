function Get-EntraApplicationAudit {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeServicePrincipals,

        [Parameter()]
        [switch]$PassThruOnly
    )

    process {
        try {
            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name Microsoft.Graph.Applications -PassThruOnly
                if (-not $moduleCheck.IsAvailable) { throw 'Microsoft.Graph.Applications is required for Get-EntraApplicationAudit.' }
            }

            $applications = Get-MgApplication -All -Property 'id,appId,displayName,createdDateTime,passwordCredentials,keyCredentials,signInAudience,web' -ErrorAction Stop

            foreach ($application in $applications) {
                [pscustomobject]@{
                    Id                      = $application.Id
                    AppId                   = $application.AppId
                    DisplayName             = $application.DisplayName
                    CreatedDateTime         = $application.CreatedDateTime
                    SignInAudience          = $application.SignInAudience
                    PasswordCredentialCount = @($application.PasswordCredentials).Count
                    KeyCredentialCount      = @($application.KeyCredentials).Count
                    ReplyUrlCount           = @($application.Web.RedirectUris).Count
                    HasCredentials          = (@($application.PasswordCredentials).Count -gt 0) -or (@($application.KeyCredentials).Count -gt 0)
                    ObjectType              = 'Application'
                }
            }

            if ($IncludeServicePrincipals.IsPresent) {
                $servicePrincipals = Get-MgServicePrincipal -All -Property 'id,appId,displayName,accountEnabled,servicePrincipalType,appOwnerOrganizationId' -ErrorAction Stop
                foreach ($servicePrincipal in $servicePrincipals) {
                    [pscustomobject]@{
                        Id                     = $servicePrincipal.Id
                        AppId                  = $servicePrincipal.AppId
                        DisplayName            = $servicePrincipal.DisplayName
                        AccountEnabled         = $servicePrincipal.AccountEnabled
                        ServicePrincipalType   = $servicePrincipal.ServicePrincipalType
                        AppOwnerOrganizationId = $servicePrincipal.AppOwnerOrganizationId
                        ObjectType             = 'ServicePrincipal'
                    }
                }
            }
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Entra application audit failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }
            throw
        }
    }
}
