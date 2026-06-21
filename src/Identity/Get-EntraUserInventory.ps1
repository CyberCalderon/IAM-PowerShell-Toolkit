function Get-EntraUserInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,

        [Parameter()]
        [ValidateRange(1, 999)]
        [int]$Top = 999,

        [Parameter()]
        [switch]$IncludeAll,

        [Parameter()]
        [switch]$PassThruOnly
    )

    process {
        try {
            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name Microsoft.Graph.Users -PassThruOnly
                if (-not $moduleCheck.IsAvailable) { throw 'Microsoft.Graph.Users is required for Get-EntraUserInventory.' }
            }

            $parameters = @{
                Property    = 'id,displayName,userPrincipalName,accountEnabled,createdDateTime,userType,department,jobTitle,mail'
                ErrorAction = 'Stop'
            }
            if ($Filter) { $parameters['Filter'] = $Filter }
            if ($IncludeAll.IsPresent) { $parameters['All'] = $true } else { $parameters['Top'] = $Top }

            $users = Get-MgUser @parameters
            foreach ($user in $users) {
                [pscustomobject]@{
                    Id                = $user.Id
                    DisplayName       = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    AccountEnabled    = $user.AccountEnabled
                    UserType          = $user.UserType
                    Department        = $user.Department
                    JobTitle          = $user.JobTitle
                    Mail              = $user.Mail
                    CreatedDateTime   = $user.CreatedDateTime
                }
            }
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Entra user inventory failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }
            throw
        }
    }
}
