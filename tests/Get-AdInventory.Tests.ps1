Describe 'Get-AdInventory' {
    . "$PSScriptRoot\..\src\Identity\Get-AdInventory.ps1"

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

        [pscustomobject]@{
            Name              = 'Ada Lovelace'
            SamAccountName    = 'alovelace'
            DistinguishedName = 'CN=Ada Lovelace,OU=Users,DC=example,DC=com'
            Enabled           = $true
            LastLogonDate     = Get-Date
            PasswordLastSet   = Get-Date
            WhenCreated       = Get-Date
            Department        = 'Engineering'
            Title             = 'Analyst'
        }
    }

    function Get-ADGroup {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string]$Filter,

            [Parameter()]
            [string[]]$Properties
        )

        [pscustomobject]@{
            Name              = 'Domain Admins'
            SamAccountName    = 'Domain Admins'
            DistinguishedName = 'CN=Domain Admins,CN=Users,DC=example,DC=com'
            GroupCategory     = 'Security'
            GroupScope        = 'Global'
            WhenCreated       = Get-Date
            ManagedBy         = $null
        }
    }

    function Get-ADComputer {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string]$Filter,

            [Parameter()]
            [string[]]$Properties
        )

        [pscustomobject]@{
            Name                   = 'WORKSTATION01'
            SamAccountName         = 'WORKSTATION01$'
            DistinguishedName      = 'CN=WORKSTATION01,OU=Computers,DC=example,DC=com'
            Enabled                = $true
            LastLogonDate          = Get-Date
            OperatingSystem        = 'Windows 11'
            OperatingSystemVersion = '10.0'
            WhenCreated            = Get-Date
        }
    }

    function Get-ADOrganizationalUnit {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string]$Filter,

            [Parameter()]
            [string[]]$Properties
        )

        [pscustomobject]@{
            Name                            = 'Users'
            DistinguishedName               = 'OU=Users,DC=example,DC=com'
            WhenCreated                     = Get-Date
            ProtectedFromAccidentalDeletion = $true
        }
    }

    It 'returns user inventory objects when User is selected' {
        $result = Get-AdInventory -ObjectType User -PassThruOnly

        $result.ObjectType | Should Be 'User'
        $result.SamAccountName | Should Be 'alovelace'
        $result.Enabled | Should Be $true
    }

    It 'returns all supported inventory object types by default' {
        $result = Get-AdInventory -PassThruOnly
        $objectTypes = $result | Select-Object -ExpandProperty ObjectType

        $objectTypes -contains 'User' | Should Be $true
        $objectTypes -contains 'Group' | Should Be $true
        $objectTypes -contains 'Computer' | Should Be $true
        $objectTypes -contains 'OrganizationalUnit' | Should Be $true
    }
}
