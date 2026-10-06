function Get-AdPrivilegedGroupMember {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$GroupName = @(
            'Domain Admins',
            'Enterprise Admins',
            'Schema Admins',
            'Administrators',
            'Account Operators',
            'Backup Operators',
            'Server Operators'
        ),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$Recursive,

        [Parameter()]
        [switch]$PassThruOnly
    )

    begin {
        $startedAt = Get-Date
        $memberParameters = @{ ErrorAction = 'Stop' }
        if ($Server) { $memberParameters['Server'] = $Server }
        if ($Recursive.IsPresent) { $memberParameters['Recursive'] = $true }
    }

    process {
        try {
            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name ActiveDirectory -PassThruOnly
                if (-not $moduleCheck.IsAvailable) { throw 'The ActiveDirectory module is required for Get-AdPrivilegedGroupMember.' }
            }
            elseif (-not (Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
                throw 'The ActiveDirectory module is required for Get-AdPrivilegedGroupMember.'
            }

            Import-Module -Name ActiveDirectory -ErrorAction Stop
            $results = [System.Collections.Generic.List[object]]::new()

            foreach ($group in $GroupName) {
                try {
                    $members = Get-ADGroupMember @memberParameters -Identity $group
                    foreach ($member in $members) {
                        $results.Add([pscustomobject]@{
                            PrivilegedGroup   = $group
                            MemberName        = $member.Name
                            SamAccountName    = $member.SamAccountName
                            ObjectClass       = $member.ObjectClass
                            DistinguishedName = $member.DistinguishedName
                            Recursive         = $Recursive.IsPresent
                        })
                    }
                }
                catch {
                    $results.Add([pscustomobject]@{
                        PrivilegedGroup   = $group
                        MemberName        = $null
                        SamAccountName    = $null
                        ObjectClass       = $null
                        DistinguishedName = $null
                        Recursive         = $Recursive.IsPresent
                        Error             = $_.Exception.Message
                    })
                }
            }

            if (-not $PassThruOnly.IsPresent -and (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue)) {
                $elapsed = New-TimeSpan -Start $startedAt -End (Get-Date)
                Initialize-Logger -LogLevel Information -LogMessage "Completed privileged group audit. Rows: $($results.Count). Elapsed milliseconds: $($elapsed.TotalMilliseconds)." -NoHostOutput | Out-Null
            }

            $results
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Privileged group audit failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }
            throw
        }
        finally {
            $startedAt = $null
        }
    }
}
