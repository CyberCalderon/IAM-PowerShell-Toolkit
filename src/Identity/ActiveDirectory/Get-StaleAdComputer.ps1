function Get-StaleAdComputer {
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
        [datetime]$ReferenceDate = (Get-Date),

        [Parameter()]
        [switch]$PassThruOnly
    )

    begin {
        $startedAt = Get-Date
        $cutoffDate = $ReferenceDate.AddDays(-$InactiveDays)
        $commonParameters = @{ ErrorAction = 'Stop' }

        if ($SearchBase) { $commonParameters['SearchBase'] = $SearchBase }
        if ($Server) { $commonParameters['Server'] = $Server }
    }

    process {
        try {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Information -LogMessage "Starting stale AD computer detection. CutoffDate: $cutoffDate." -NoHostOutput | Out-Null
            }

            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name ActiveDirectory -PassThruOnly
                if (-not $moduleCheck.IsAvailable) {
                    throw 'The ActiveDirectory module is required for Get-StaleAdComputer.'
                }
            }
            elseif (-not (Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
                throw 'The ActiveDirectory module is required for Get-StaleAdComputer.'
            }

            Import-Module -Name ActiveDirectory -ErrorAction Stop
            $computerFilter = if ($IncludeDisabled.IsPresent) { '*' } else { 'Enabled -eq $true' }
            $computers = Get-ADComputer @commonParameters -Filter $computerFilter -Properties Enabled, LastLogonDate, OperatingSystem, OperatingSystemVersion, WhenCreated
            $staleComputers = [System.Collections.Generic.List[object]]::new()

            foreach ($computer in $computers) {
                if ($computer.LastLogonDate -and $computer.LastLogonDate -lt $cutoffDate) {
                    $staleComputers.Add([pscustomobject]@{
                        SamAccountName         = $computer.SamAccountName
                        Name                   = $computer.Name
                        DistinguishedName      = $computer.DistinguishedName
                        Enabled                = $computer.Enabled
                        LastLogonDate          = $computer.LastLogonDate
                        DaysSinceLastLogon     = [int](New-TimeSpan -Start $computer.LastLogonDate -End $ReferenceDate).TotalDays
                        OperatingSystem        = $computer.OperatingSystem
                        OperatingSystemVersion = $computer.OperatingSystemVersion
                        WhenCreated            = $computer.WhenCreated
                        InactiveDays           = $InactiveDays
                        CutoffDate             = $cutoffDate
                    })
                }
            }

            if (-not $PassThruOnly.IsPresent -and (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue)) {
                $elapsed = New-TimeSpan -Start $startedAt -End (Get-Date)
                Initialize-Logger -LogLevel Information -LogMessage "Completed stale AD computer detection. Stale computers found: $($staleComputers.Count). Elapsed milliseconds: $($elapsed.TotalMilliseconds)." -NoHostOutput | Out-Null
            }

            $staleComputers
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Stale AD computer detection failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }
            throw
        }
        finally {
            $startedAt = $null
            $cutoffDate = $null
        }
    }
}
