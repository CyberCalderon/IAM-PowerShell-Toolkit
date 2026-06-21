Describe 'Initialize-Environment' {
    . "$PSScriptRoot\..\src\Core\Initialize-Environment.ps1"

    It 'initializes the repository environment without module checks' {
        $repositoryRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
        $testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $configurationPath = Join-Path -Path $testRoot -ChildPath 'utilitybelt.config.psd1'

        $result = Initialize-Environment -RepositoryRoot $repositoryRoot.Path -ConfigurationPath $configurationPath -SkipModuleCheck

        $result.RepositoryRoot | Should Be $repositoryRoot.Path
        $result.PowerShellVersion | Should Not BeNullOrEmpty
        $result.ModuleResults.Count | Should Be 0
    }
}
