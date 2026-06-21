function Get-ScheduledTaskInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskPath = '*',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskName = '*'
    )

    process {
        try {
            $tasks = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
            foreach ($task in $tasks) {
                $taskInfo = $null
                try {
                    $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
                }
                catch {
                    $taskInfo = $null
                }

                [pscustomobject]@{
                    TaskName      = $task.TaskName
                    TaskPath      = $task.TaskPath
                    State         = $task.State
                    Author        = $task.Author
                    Description   = $task.Description
                    LastRunTime   = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
                    NextRunTime   = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
                    LastTaskResult = if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
                }
            }
        }
        catch {
            throw "Scheduled task inventory failed. $($_.Exception.Message)"
        }
    }
}
