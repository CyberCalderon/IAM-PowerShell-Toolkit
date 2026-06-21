Describe 'Initialize-Logger' {
    . "$PSScriptRoot\..\src\Core\Initialize-Logger.ps1"

    It 'writes a structured log entry and returns metadata' {
        $testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $result = Initialize-Logger -LogLevel Information -LogMessage 'Pester logger test.' -LogDirectory $testRoot -NoHostOutput
        $logContent = Get-Content -Path $result.LogPath -Raw | ConvertFrom-Json

        $result.Level | Should Be 'Information'
        $result.Message | Should Be 'Pester logger test.'
        $logContent.Level | Should Be 'Information'
        $logContent.Message | Should Be 'Pester logger test.'
    }

    It 'rejects unsupported log levels' {
        $thrown = $false

        try {
            Initialize-Logger -LogLevel Debug -LogMessage 'Invalid level.' -NoHostOutput
        }
        catch {
            $thrown = $true
        }

        $thrown | Should Be $true
    }
}
