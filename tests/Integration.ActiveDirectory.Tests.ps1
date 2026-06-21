Describe 'Active Directory integration lab' -Tags 'Integration', 'Integration.AD' {
    $adServer = $env:UTILITYBELT_AD_SERVER
    $adSearchBase = $env:UTILITYBELT_AD_SEARCHBASE
    $integrationEnabled = -not [string]::IsNullOrWhiteSpace($adServer) -and -not [string]::IsNullOrWhiteSpace($adSearchBase)

    if (-not $integrationEnabled) {
        It 'is disabled until UTILITYBELT_AD_SERVER and UTILITYBELT_AD_SEARCHBASE are set' {
            $true | Should Be $true
        }
    }
    else {
        Import-Module "$PSScriptRoot\..\UtilityBelt.psd1" -Force

        It 'returns lab users, groups, computers, and OUs from the configured search base' {
            $inventory = Get-AdInventory -SearchBase $adSearchBase -Server $adServer -IncludeDisabled -PassThruOnly
            $objectTypes = $inventory | Select-Object -ExpandProperty ObjectType -Unique

            $objectTypes -contains 'User' | Should Be $true
            $objectTypes -contains 'Group' | Should Be $true
            $objectTypes -contains 'Computer' | Should Be $true
            $objectTypes -contains 'OrganizationalUnit' | Should Be $true
            ($inventory | Where-Object { $_.SamAccountName -eq 'ub-active' }).Name | Should Be 'UB Lab Active User'
            ($inventory | Where-Object { $_.SamAccountName -eq 'ub-disabled' }).Enabled | Should Be $false
        }

        It 'excludes disabled AD objects unless IncludeDisabled is supplied' {
            $enabledOnly = Get-AdInventory -ObjectType User -SearchBase $adSearchBase -Server $adServer -PassThruOnly
            $disabledUsers = $enabledOnly | Where-Object { $_.SamAccountName -eq 'ub-disabled' }

            @($disabledUsers).Count | Should Be 0
        }

        It 'finds stale and never-logged-on lab users' {
            $referenceDate = (Get-Date).AddDays(91)
            $staleUsers = Get-StaleAdUser -InactiveDays 90 -SearchBase $adSearchBase -Server $adServer -IncludeDisabled -IncludeNeverLoggedOn -ReferenceDate $referenceDate -PassThruOnly
            $samAccountNames = $staleUsers | Select-Object -ExpandProperty SamAccountName

            $samAccountNames -contains 'ub-stale' | Should Be $true
            $samAccountNames -contains 'ub-never' | Should Be $true
            $samAccountNames -contains 'ub-active' | Should Be $false
        }

        It 'finds stale lab computer accounts' {
            $staleComputers = Get-StaleAdComputer -InactiveDays 90 -SearchBase $adSearchBase -Server $adServer -IncludeDisabled -PassThruOnly
            $samAccountNames = $staleComputers | Select-Object -ExpandProperty SamAccountName

            $samAccountNames -contains 'UB-STALE01$' | Should Be $true
            $samAccountNames -contains 'UB-ACTIVE01$' | Should Be $false
        }

        It 'returns direct and nested lab privileged members' {
            $members = Get-AdPrivilegedGroupMember -Server $adServer -Recursive -PassThruOnly
            $samAccountNames = $members | Select-Object -ExpandProperty SamAccountName

            $samAccountNames -contains 'ub-priv-stale' | Should Be $true
            $samAccountNames -contains 'ub-pwd-never' | Should Be $true
        }

        It 'returns the default domain password policy' {
            $policy = Get-AdPasswordPolicyReport -Server $adServer

            $policy.MinPasswordLength -ge 0 | Should Be $true
            $null -ne $policy.ComplexityEnabled | Should Be $true
        }

        if ($env:UTILITYBELT_AD_ENABLE_DEFAULT_CONTEXT_TESTS -eq '1') {
            It 'flags weak lab privileged accounts from the current AD context' {
                $findings = Get-WeakAdPrivilegedAccount -StaleDays 90
                $samAccountNames = $findings | Select-Object -ExpandProperty SamAccountName

                $samAccountNames -contains 'ub-priv-stale' | Should Be $true
                $samAccountNames -contains 'ub-pwd-never' | Should Be $true
            }
        }
        else {
            It 'does not run default-context AD security tests unless explicitly enabled' {
                $true | Should Be $true
            }
        }
    }
}
