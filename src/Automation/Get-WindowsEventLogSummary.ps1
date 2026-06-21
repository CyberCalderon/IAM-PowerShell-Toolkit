function Get-WindowsEventLogSummary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogName = 'System',

        [Parameter()]
        [ValidateRange(1, 10000)]
        [int]$MaxEvents = 100,

        [Parameter()]
        [ValidateSet('Error', 'Warning', 'Information')]
        [string[]]$Level = @('Error', 'Warning'),

        [Parameter()]
        [datetime]$StartTime = (Get-Date).AddDays(-7)
    )

    process {
        try {
            $levelMap = @{
                Information = 4
                Warning     = 3
                Error       = 2
            }

            $events = Get-WinEvent -FilterHashtable @{
                LogName   = $LogName
                Level     = @($Level | ForEach-Object { $levelMap[$_] })
                StartTime = $StartTime
            } -MaxEvents $MaxEvents -ErrorAction Stop

            foreach ($event in $events) {
                [pscustomobject]@{
                    LogName      = $event.LogName
                    TimeCreated  = $event.TimeCreated
                    Id           = $event.Id
                    LevelDisplayName = $event.LevelDisplayName
                    ProviderName = $event.ProviderName
                    MachineName  = $event.MachineName
                    Message      = $event.Message
                }
            }
        }
        catch {
            throw "Windows event log summary failed. $($_.Exception.Message)"
        }
    }
}
