Describe 'Get-UtilityBeltConfiguration' {
    . "$PSScriptRoot\..\src\Core\Get-UtilityBeltConfiguration.ps1"

    It 'returns default configuration when no file exists and CreateDefault is not used' {
        $testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $configurationPath = Join-Path -Path $testRoot -ChildPath 'utilitybelt.config.psd1'

        $result = Get-UtilityBeltConfiguration -ConfigurationPath $configurationPath

        $result.ProjectName | Should Be 'PowerShell AI Utility Belt'
        $result.PowerShell.MinimumVersion | Should Be '7.0'
        (Test-Path -Path $configurationPath -PathType Leaf) | Should Be $false
    }

    It 'creates a default configuration file when requested' {
        $testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $configurationPath = Join-Path -Path $testRoot -ChildPath 'utilitybelt.config.psd1'

        $result = Get-UtilityBeltConfiguration -ConfigurationPath $configurationPath -CreateDefault

        $result.ProjectName | Should Be 'PowerShell AI Utility Belt'
        (Test-Path -Path $configurationPath -PathType Leaf) | Should Be $true
    }
}
