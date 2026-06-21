Describe 'Get-StaleAdUser' {
    . "$PSScriptRoot\..\src\Identity\Get-StaleAdUser.ps1"

    function Initialize-Logger {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$LogLevel,

            [Parameter(Mandatory)]
            [string]$LogMessage,

            [Parameter()]
            [switch]$NoHostOutput
        )
    }

    function Test-RequiredModule {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string[]]$Name,

            [Parameter()]
            [switch]$PassThruOnly
        )

        [pscustomobject]@{
            Name             = 'ActiveDirectory'
            IsAvailable      = $true
            MeetsVersion     = $true
            RequiredVersion  = $null
            InstalledVersion = '1.0.0.0'
            Imported         = $false
            Status           = 'Available'
            Message          = 'Module is available.'
        }
    }

    function Import-Module {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string]$Name
        )
    }

    function Get-ADUser {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string]$Filter,

            [Parameter()]
            [string[]]$Properties
        )

        $referenceDate = [datetime]'2026-06-03T00:00:00'

        @(
            [pscustomobject]@{
                Name              = 'Stale User'
                SamAccountName    = 'stale.user'
                DistinguishedName = 'CN=Stale User,OU=Users,DC=example,DC=com'
                Enabled           = $true
                LastLogonDate     = $referenceDate.AddDays(-120)
                PasswordLastSet   = $referenceDate.AddDays(-130)
                WhenCreated       = $referenceDate.AddDays(-300)
                Department        = 'Operations'
                Title             = 'Analyst'
            }
            [pscustomobject]@{
                Name              = 'Active User'
                SamAccountName    = 'active.user'
                DistinguishedName = 'CN=Active User,OU=Users,DC=example,DC=com'
                Enabled           = $true
                LastLogonDate     = $referenceDate.AddDays(-10)
                PasswordLastSet   = $referenceDate.AddDays(-30)
                WhenCreated       = $referenceDate.AddDays(-300)
                Department        = 'Operations'
                Title             = 'Engineer'
            }
            [pscustomobject]@{
                Name              = 'Never Logged On'
                SamAccountName    = 'never.user'
                DistinguishedName = 'CN=Never Logged On,OU=Users,DC=example,DC=com'
                Enabled           = $true
                LastLogonDate     = $null
                PasswordLastSet   = $referenceDate.AddDays(-100)
                WhenCreated       = $referenceDate.AddDays(-180)
                Department        = 'Operations'
                Title             = 'Intern'
            }
        )
    }

    It 'returns users with last logon older than the cutoff date' {
        $result = Get-StaleAdUser -InactiveDays 90 -ReferenceDate ([datetime]'2026-06-03T00:00:00') -PassThruOnly

        $result.Count | Should Be 1
        $result.SamAccountName | Should Be 'stale.user'
        $result.StaleReason | Should Be 'LastLogonDateOlderThanCutoff'
    }

    It 'includes old never-logged-on users when requested' {
        $result = Get-StaleAdUser -InactiveDays 90 -ReferenceDate ([datetime]'2026-06-03T00:00:00') -IncludeNeverLoggedOn -PassThruOnly
        $accountNames = $result | Select-Object -ExpandProperty SamAccountName

        $accountNames -contains 'stale.user' | Should Be $true
        $accountNames -contains 'never.user' | Should Be $true
    }
}
