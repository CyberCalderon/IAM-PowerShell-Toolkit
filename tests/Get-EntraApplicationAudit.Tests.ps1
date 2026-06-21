Describe 'Get-EntraApplicationAudit' {
    . "$PSScriptRoot\..\src\Identity\Get-EntraApplicationAudit.ps1"

    function Test-RequiredModule { [pscustomobject]@{ IsAvailable = $true } }
    function Get-MgApplication {
        [pscustomobject]@{ Id = 'app-1'; AppId = 'client-1'; DisplayName = 'Automation App'; CreatedDateTime = [datetime]'2026-01-01'; SignInAudience = 'AzureADMyOrg'; PasswordCredentials = @([pscustomobject]@{}); KeyCredentials = @(); Web = [pscustomobject]@{ RedirectUris = @('https://localhost') } }
    }

    It 'reports credential counts for applications' {
        $result = Get-EntraApplicationAudit
        $result.DisplayName | Should Be 'Automation App'
        $result.PasswordCredentialCount | Should Be 1
        $result.HasCredentials | Should Be $true
    }
}
