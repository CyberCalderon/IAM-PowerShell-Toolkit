function Get-StaleAdUser {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 3650)]
        [int]$InactiveDays = 90,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SearchBase,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter()]
        [switch]$IncludeDisabled,

        [Parameter()]
        [switch]$IncludeNeverLoggedOn,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date),

        [Parameter()]
        [switch]$PassThruOnly
    )

    begin {
        $startedAt = Get-Date
        $cutoffDate = $ReferenceDate.AddDays(-$InactiveDays)
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
                Initialize-Logger -LogLevel Information -LogMessage "Starting stale AD user detection. InactiveDays: $InactiveDays. CutoffDate: $cutoffDate." -NoHostOutput | Out-Null
            }

            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name ActiveDirectory -PassThruOnly

                if (-not $moduleCheck.IsAvailable) {
                    throw 'The ActiveDirectory module is required for Get-StaleAdUser. Install RSAT Active Directory tools or run from a system with the module available.'
                }
            }
            elseif (-not (Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
                throw 'The ActiveDirectory module is required for Get-StaleAdUser. Install RSAT Active Directory tools or run from a system with the module available.'
            }

            Import-Module -Name ActiveDirectory -ErrorAction Stop

            $userFilter = if ($IncludeDisabled.IsPresent) { '*' } else { 'Enabled -eq $true' }
            $users = Get-ADUser @commonParameters -Filter $userFilter -Properties Enabled, LastLogonDate, PasswordLastSet, WhenCreated, Department, Title
            $staleUsers = [System.Collections.Generic.List[object]]::new()

            foreach ($user in $users) {
                $hasLoggedOn = $null -ne $user.LastLogonDate
                $isInactive = $hasLoggedOn -and $user.LastLogonDate -lt $cutoffDate
                $isNeverLoggedOnAndOld = (-not $hasLoggedOn) -and $IncludeNeverLoggedOn.IsPresent -and $user.WhenCreated -lt $cutoffDate

                if ($isInactive -or $isNeverLoggedOnAndOld) {
                    $reason = if ($isInactive) {
                        'LastLogonDateOlderThanCutoff'
                    }
                    else {
                        'NeverLoggedOnAndCreatedBeforeCutoff'
                    }

                    $daysSinceLastLogon = if ($hasLoggedOn) {
                        [int](New-TimeSpan -Start $user.LastLogonDate -End $ReferenceDate).TotalDays
                    }
                    else {
                        $null
                    }

                    $staleUsers.Add([pscustomobject]@{
                        SamAccountName     = $user.SamAccountName
                        Name               = $user.Name
                        DistinguishedName  = $user.DistinguishedName
                        Enabled            = $user.Enabled
                        LastLogonDate      = $user.LastLogonDate
                        DaysSinceLastLogon = $daysSinceLastLogon
                        PasswordLastSet    = $user.PasswordLastSet
                        WhenCreated        = $user.WhenCreated
                        Department         = $user.Department
                        Title              = $user.Title
                        InactiveDays       = $InactiveDays
                        CutoffDate         = $cutoffDate
                        StaleReason        = $reason
                    })
                }
            }

            $elapsed = New-TimeSpan -Start $startedAt -End (Get-Date)

            if (-not $PassThruOnly.IsPresent -and (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue)) {
                Initialize-Logger -LogLevel Information -LogMessage "Completed stale AD user detection. Stale users found: $($staleUsers.Count). Elapsed milliseconds: $($elapsed.TotalMilliseconds)." -NoHostOutput | Out-Null
            }

            $staleUsers
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Stale AD user detection failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }

            throw
        }
        finally {
            $startedAt = $null
            $cutoffDate = $null
        }
    }
}
