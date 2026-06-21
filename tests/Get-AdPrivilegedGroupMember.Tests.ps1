Describe 'Get-AdPrivilegedGroupMember' {
    . "$PSScriptRoot\..\src\Identity\Get-AdPrivilegedGroupMember.ps1"

    function Test-RequiredModule { [pscustomobject]@{ IsAvailable = $true } }
    function Import-Module { param([string]$Name) }
    function Get-ADGroupMember {
        param([string]$Identity)
        [pscustomobject]@{ Name = 'Admin User'; SamAccountName = 'admin.user'; ObjectClass = 'user'; DistinguishedName = 'CN=Admin User,DC=example,DC=com' }
    }

    It 'returns privileged group members' {
        $result = Get-AdPrivilegedGroupMember -GroupName 'Domain Admins' -PassThruOnly
        $result.PrivilegedGroup | Should Be 'Domain Admins'
        $result.SamAccountName | Should Be 'admin.user'
    }
}
