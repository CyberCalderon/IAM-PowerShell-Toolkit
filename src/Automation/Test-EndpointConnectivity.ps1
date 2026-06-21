function Test-EndpointConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int[]]$TcpPort = @(5985, 3389),

        [Parameter()]
        [switch]$SkipPing
    )

    process {
        foreach ($computer in $ComputerName) {
            $pingSucceeded = $null
            if (-not $SkipPing.IsPresent) {
                try {
                    $pingSucceeded = Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction Stop
                }
                catch {
                    $pingSucceeded = $false
                }
            }

            foreach ($port in $TcpPort) {
                try {
                    $tcpResult = Test-NetConnection -ComputerName $computer -Port $port -WarningAction SilentlyContinue -ErrorAction Stop
                    [pscustomobject]@{
                        ComputerName = $computer
                        PingSucceeded = $pingSucceeded
                        TcpPort      = $port
                        TcpSucceeded = [bool]$tcpResult.TcpTestSucceeded
                        RemoteAddress = $tcpResult.RemoteAddress
                    }
                }
                catch {
                    [pscustomobject]@{
                        ComputerName = $computer
                        PingSucceeded = $pingSucceeded
                        TcpPort      = $port
                        TcpSucceeded = $false
                        RemoteAddress = $null
                        Error        = $_.Exception.Message
                    }
                }
            }
        }
    }
}
