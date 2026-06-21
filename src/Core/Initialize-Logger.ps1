function Initialize-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Verbose', 'Information', 'Warning', 'Error')]
        [string]$LogLevel,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LogMessage,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogDirectory = (Join-Path -Path $PWD -ChildPath 'logs'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogFileName = 'utility-belt.log',

        [Parameter()]
        [ValidateRange(1, 1024)]
        [int]$MaxLogFileSizeMB = 10,

        [Parameter()]
        [switch]$NoHostOutput
    )

    begin {
        $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffK'
        $logPath = Join-Path -Path $LogDirectory -ChildPath $LogFileName
        $maxLogFileSizeBytes = $MaxLogFileSizeMB * 1MB

        $hostColorMap = @{
            Verbose     = 'Cyan'
            Information = 'Green'
            Warning     = 'Yellow'
            Error       = 'Red'
        }
    }

    process {
        try {
            if (-not (Test-Path -Path $LogDirectory -PathType Container)) {
                New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }

            if (Test-Path -Path $logPath -PathType Leaf) {
                $currentLogFile = Get-Item -Path $logPath -ErrorAction Stop

                if ($currentLogFile.Length -ge $maxLogFileSizeBytes) {
                    $rotationTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                    $rotatedLogPath = Join-Path -Path $LogDirectory -ChildPath "$($currentLogFile.BaseName)-$rotationTimestamp$($currentLogFile.Extension)"
                    Move-Item -Path $logPath -Destination $rotatedLogPath -Force -ErrorAction Stop
                }
            }

            $entry = [ordered]@{
                Timestamp = $timestamp
                Level     = $LogLevel
                Message   = $LogMessage
                User      = [System.Environment]::UserName
                Host      = [System.Environment]::MachineName
                ProcessId = [System.Environment]::ProcessId
            }

            $jsonEntry = $entry | ConvertTo-Json -Compress
            Add-Content -Path $logPath -Value $jsonEntry -Encoding UTF8 -ErrorAction Stop

            if (-not $NoHostOutput.IsPresent) {
                $consoleMessage = "[$timestamp] [$LogLevel] $LogMessage"
                Write-Host $consoleMessage -ForegroundColor $hostColorMap[$LogLevel]
            }

            [pscustomobject]@{
                Timestamp = $timestamp
                Level     = $LogLevel
                Message   = $LogMessage
                LogPath   = $logPath
            }
        }
        catch {
            $errorMessage = "Logger failure while writing '$LogLevel' entry. $($_.Exception.Message)"
            Write-Error -Message $errorMessage -ErrorAction Continue
            throw
        }
        finally {
            $timestamp = $null
            $logPath = $null
            $maxLogFileSizeBytes = $null
        }
    }
}
