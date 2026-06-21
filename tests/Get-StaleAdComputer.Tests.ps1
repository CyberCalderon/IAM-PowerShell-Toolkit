Describe 'Get-StaleAdComputer' {
    . "$PSScriptRoot\..\src\Identity\Get-StaleAdComputer.ps1"

    function Test-RequiredModule { [pscustomobject]@{ IsAvailable = $true } }
    function Import-Module { param([string]$Name) }
    function Get-ADComputer {
        param([string]$Filter, [string[]]$Properties)
        $referenceDate = [datetime]'2026-06-03T00:00:00'
        @(
            [pscustomobject]@{ Name = 'STALE01'; SamAccountName = 'STALE01$'; DistinguishedName = 'CN=STALE01,DC=example,DC=com'; Enabled = $true; LastLogonDate = $referenceDate.AddDays(-120); OperatingSystem = 'Windows 11'; OperatingSystemVersion = '10.0'; WhenCreated = $referenceDate.AddDays(-300) }
            [pscustomobject]@{ Name = 'ACTIVE01'; SamAccountName = 'ACTIVE01$'; DistinguishedName = 'CN=ACTIVE01,DC=example,DC=com'; Enabled = $true; LastLogonDate = $referenceDate.AddDays(-10); OperatingSystem = 'Windows 11'; OperatingSystemVersion = '10.0'; WhenCreated = $referenceDate.AddDays(-300) }
        )
    }

    It 'returns computers with last logon older than cutoff' {
        $result = Get-StaleAdComputer -InactiveDays 90 -ReferenceDate ([datetime]'2026-06-03T00:00:00') -PassThruOnly
        $result.Count | Should Be 1
        $result.SamAccountName | Should Be 'STALE01$'
    }
}
