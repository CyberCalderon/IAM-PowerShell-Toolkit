Describe 'Export-EntraConditionalAccessPolicy' {
    . "$PSScriptRoot\..\src\Identity\Export-EntraConditionalAccessPolicy.ps1"

    function Test-RequiredModule { [pscustomobject]@{ IsAvailable = $true } }
    function Get-MgIdentityConditionalAccessPolicy {
        [pscustomobject]@{ Id = 'policy-1'; DisplayName = 'Require MFA'; State = 'enabled'; CreatedDateTime = [datetime]'2026-01-01'; ModifiedDateTime = [datetime]'2026-02-01'; Conditions = @{}; GrantControls = @{}; SessionControls = @{} }
    }

    It 'returns conditional access policy export objects' {
        $result = Export-EntraConditionalAccessPolicy -PassThru
        $result.DisplayName | Should Be 'Require MFA'
        $result.State | Should Be 'enabled'
    }
}
