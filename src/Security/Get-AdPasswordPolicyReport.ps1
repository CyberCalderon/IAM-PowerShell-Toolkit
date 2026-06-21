function Get-AdPasswordPolicyReport {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    process {
        try {
            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name ActiveDirectory -PassThruOnly
                if (-not $moduleCheck.IsAvailable) { throw 'The ActiveDirectory module is required for Get-AdPasswordPolicyReport.' }
            }
            Import-Module -Name ActiveDirectory -ErrorAction Stop

            $parameters = @{ ErrorAction = 'Stop' }
            if ($Server) { $parameters['Server'] = $Server }
            $policy = Get-ADDefaultDomainPasswordPolicy @parameters

            [pscustomobject]@{
                ComplexityEnabled           = $policy.ComplexityEnabled
                LockoutDuration             = $policy.LockoutDuration
                LockoutObservationWindow    = $policy.LockoutObservationWindow
                LockoutThreshold            = $policy.LockoutThreshold
                MaxPasswordAge              = $policy.MaxPasswordAge
                MinPasswordAge              = $policy.MinPasswordAge
                MinPasswordLength           = $policy.MinPasswordLength
                PasswordHistoryCount        = $policy.PasswordHistoryCount
                ReversibleEncryptionEnabled = $policy.ReversibleEncryptionEnabled
            }
        }
        catch {
            throw "AD password policy report failed. $($_.Exception.Message)"
        }
    }
}
