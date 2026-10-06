function Get-AdInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('User', 'Group', 'Computer', 'OrganizationalUnit', 'All')]
        [string[]]$ObjectType = @('All'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SearchBase,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$IncludeDisabled,

        [Parameter()]
        [switch]$PassThruOnly
    )

    begin {
        $startedAt = Get-Date
        $selectedTypes = if ($ObjectType -contains 'All') {
            @('User', 'Group', 'Computer', 'OrganizationalUnit')
        }
        else {
            $ObjectType
        }

        $commonParameters = @{
            ErrorAction = 'Stop'
        }

        if ($SearchBase) {
            $commonParameters['SearchBase'] = $SearchBase
        }

        if ($Server) {
            $commonParameters['Server'] = $Server
        }
    }

    process {
        try {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Information -LogMessage 'Starting Active Directory inventory collection.' -NoHostOutput | Out-Null
            }

            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name ActiveDirectory -PassThruOnly

                if (-not $moduleCheck.IsAvailable) {
                    throw 'The ActiveDirectory module is required for Get-AdInventory. Install RSAT Active Directory tools or run from a system with the module available.'
                }
            }
            elseif (-not (Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
                throw 'The ActiveDirectory module is required for Get-AdInventory. Install RSAT Active Directory tools or run from a system with the module available.'
            }

            Import-Module -Name ActiveDirectory -ErrorAction Stop

            $inventory = [System.Collections.Generic.List[object]]::new()

            if ($selectedTypes -contains 'User') {
                $userFilter = if ($IncludeDisabled.IsPresent) { '*' } else { 'Enabled -eq $true' }
                $users = Get-ADUser @commonParameters -Filter $userFilter -Properties Enabled, LastLogonDate, PasswordLastSet, WhenCreated, Department, Title

                foreach ($user in $users) {
                    $inventory.Add([pscustomobject]@{
                        ObjectType      = 'User'
                        Name            = $user.Name
                        SamAccountName  = $user.SamAccountName
                        DistinguishedName = $user.DistinguishedName
                        Enabled         = $user.Enabled
                        LastLogonDate   = $user.LastLogonDate
                        PasswordLastSet = $user.PasswordLastSet
                        WhenCreated     = $user.WhenCreated
                        Department      = $user.Department
                        Title           = $user.Title
                    })
                }
            }

            if ($selectedTypes -contains 'Group') {
                $groups = Get-ADGroup @commonParameters -Filter '*' -Properties GroupCategory, GroupScope, WhenCreated, ManagedBy

                foreach ($group in $groups) {
                    $inventory.Add([pscustomobject]@{
                        ObjectType        = 'Group'
                        Name              = $group.Name
                        SamAccountName    = $group.SamAccountName
                        DistinguishedName = $group.DistinguishedName
                        GroupCategory     = $group.GroupCategory
                        GroupScope        = $group.GroupScope
                        WhenCreated       = $group.WhenCreated
                        ManagedBy         = $group.ManagedBy
                    })
                }
            }

            if ($selectedTypes -contains 'Computer') {
                $computerFilter = if ($IncludeDisabled.IsPresent) { '*' } else { 'Enabled -eq $true' }
                $computers = Get-ADComputer @commonParameters -Filter $computerFilter -Properties Enabled, LastLogonDate, OperatingSystem, OperatingSystemVersion, WhenCreated

                foreach ($computer in $computers) {
                    $inventory.Add([pscustomobject]@{
                        ObjectType             = 'Computer'
                        Name                   = $computer.Name
                        SamAccountName         = $computer.SamAccountName
                        DistinguishedName      = $computer.DistinguishedName
                        Enabled                = $computer.Enabled
                        LastLogonDate          = $computer.LastLogonDate
                        OperatingSystem        = $computer.OperatingSystem
                        OperatingSystemVersion = $computer.OperatingSystemVersion
                        WhenCreated            = $computer.WhenCreated
                    })
                }
            }

            if ($selectedTypes -contains 'OrganizationalUnit') {
                $organizationalUnits = Get-ADOrganizationalUnit @commonParameters -Filter '*' -Properties WhenCreated, ProtectedFromAccidentalDeletion

                foreach ($organizationalUnit in $organizationalUnits) {
                    $inventory.Add([pscustomobject]@{
                        ObjectType                      = 'OrganizationalUnit'
                        Name                            = $organizationalUnit.Name
                        DistinguishedName               = $organizationalUnit.DistinguishedName
                        WhenCreated                     = $organizationalUnit.WhenCreated
                        ProtectedFromAccidentalDeletion = $organizationalUnit.ProtectedFromAccidentalDeletion
                    })
                }
            }

            $elapsed = New-TimeSpan -Start $startedAt -End (Get-Date)

            if (-not $PassThruOnly.IsPresent -and (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue)) {
                Initialize-Logger -LogLevel Information -LogMessage "Completed Active Directory inventory collection. Objects collected: $($inventory.Count). Elapsed milliseconds: $($elapsed.TotalMilliseconds)." -NoHostOutput | Out-Null
            }

            $inventory
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Active Directory inventory collection failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }

            throw
        }
        finally {
            $startedAt = $null
        }
    }
}
