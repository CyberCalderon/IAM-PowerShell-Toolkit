Describe 'Automation commands' {
    . "$PSScriptRoot\..\src\Automation\Get-ServiceStatusReport.ps1"
    . "$PSScriptRoot\..\src\Automation\Test-EndpointConnectivity.ps1"

    function Get-Service {
        param([string[]]$Name)
        [pscustomobject]@{ Name = 'Spooler'; DisplayName = 'Print Spooler'; Status = 'Running'; StartType = 'Automatic'; ServiceType = 'Win32OwnProcess' }
    }

    function Test-Connection { $true }
    function Test-NetConnection {
        [pscustomobject]@{ TcpTestSucceeded = $true; RemoteAddress = '127.0.0.1' }
    }

    It 'returns service report rows' {
        $result = Get-ServiceStatusReport -Name Spooler -ComputerName $env:COMPUTERNAME
        $result.Name | Should Be 'Spooler'
        $result.Status | Should Be 'Running'
    }

    It 'returns endpoint connectivity rows' {
        $result = Test-EndpointConnectivity -ComputerName localhost -TcpPort 5985
        $result.TcpSucceeded | Should Be $true
    }
}
