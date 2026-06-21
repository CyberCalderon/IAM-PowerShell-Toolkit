function Get-IdentitySecuritySummary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$StaleUsers,

        [Parameter()]
        [object[]]$StaleComputers,

        [Parameter()]
        [object[]]$PrivilegedMembers,

        [Parameter()]
        [object[]]$WeakPrivilegedAccounts,

        [Parameter()]
        [object]$PasswordPolicy
    )

    process {
        [pscustomobject]@{
            GeneratedAt                 = Get-Date
            StaleUserCount              = @($StaleUsers).Count
            StaleComputerCount          = @($StaleComputers).Count
            PrivilegedMembershipCount   = @($PrivilegedMembers).Count
            WeakPrivilegedAccountCount  = @($WeakPrivilegedAccounts).Count
            PasswordPolicyMinLength     = if ($PasswordPolicy) { $PasswordPolicy.MinPasswordLength } else { $null }
            PasswordPolicyComplexity    = if ($PasswordPolicy) { $PasswordPolicy.ComplexityEnabled } else { $null }
            RecommendedNextAction       = 'Review non-zero counts, validate privileged memberships, and export detailed findings for remediation planning.'
        }
    }
}
