Describe 'Get-EntraUserInventory' {
    . "$PSScriptRoot\..\src\Identity\Get-EntraUserInventory.ps1"

    function Test-RequiredModule { [pscustomobject]@{ IsAvailable = $true } }
    function Get-MgUser {
        [pscustomobject]@{ Id = '1'; DisplayName = 'Ada Lovelace'; UserPrincipalName = 'ada@example.com'; AccountEnabled = $true; UserType = 'Member'; Department = 'Engineering'; JobTitle = 'Analyst'; Mail = 'ada@example.com'; CreatedDateTime = [datetime]'2026-01-01' }
    }

    It 'maps Microsoft Graph users to inventory objects' {
        $result = Get-EntraUserInventory -Top 1 -PassThruOnly
        $result.UserPrincipalName | Should Be 'ada@example.com'
        $result.AccountEnabled | Should Be $true
    }
}
