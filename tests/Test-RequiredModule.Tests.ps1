Describe 'Test-RequiredModule' {
    . "$PSScriptRoot\..\src\Core\Test-RequiredModule.ps1"

    It 'reports a missing module without throwing' {
        $result = Test-RequiredModule -Name NoSuchModuleForUtilityBeltTests -PassThruOnly

        $result.Name | Should Be 'NoSuchModuleForUtilityBeltTests'
        $result.IsAvailable | Should Be $false
        $result.MeetsVersion | Should Be $false
        $result.Status | Should Be 'Missing'
    }

    It 'reports a version mismatch for an installed module below the required version' {
        $result = Test-RequiredModule -Name Microsoft.PowerShell.Management -MinimumVersion @{ 'Microsoft.PowerShell.Management' = '999.0.0' } -PassThruOnly

        $result.Name | Should Be 'Microsoft.PowerShell.Management'
        $result.IsAvailable | Should Be $true
        $result.MeetsVersion | Should Be $false
        $result.Status | Should Be 'VersionMismatch'
    }
}
