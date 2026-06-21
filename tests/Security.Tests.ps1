Describe 'Security commands' {
    . "$PSScriptRoot\..\src\Security\Get-IdentitySecuritySummary.ps1"
    . "$PSScriptRoot\..\src\Security\Get-LocalAdministratorAudit.ps1"

    function Get-LocalGroupMember {
        [pscustomobject]@{ Name = 'BUILTIN\Administrators'; ObjectClass = 'Group'; PrincipalSource = 'Local' }
    }

    It 'summarizes identity security counts' {
        $summary = Get-IdentitySecuritySummary -StaleUsers @(@{}) -StaleComputers @(@{}, @{}) -PrivilegedMembers @(@{}) -WeakPrivilegedAccounts @()
        $summary.StaleUserCount | Should Be 1
        $summary.StaleComputerCount | Should Be 2
    }

    It 'returns local administrator members' {
        $result = Get-LocalAdministratorAudit -ComputerName $env:COMPUTERNAME
        $result.GroupName | Should Be 'Administrators'
        $result.Name | Should Be 'BUILTIN\Administrators'
    }
}
