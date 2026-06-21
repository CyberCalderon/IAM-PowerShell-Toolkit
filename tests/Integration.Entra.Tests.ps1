Describe 'Microsoft Entra integration lab' -Tags 'Integration', 'Integration.Entra' {
    $tenantId = $env:UTILITYBELT_ENTRA_TENANT_ID
    $graphScopes = $env:UTILITYBELT_GRAPH_SCOPES
    $integrationEnabled = -not [string]::IsNullOrWhiteSpace($tenantId) -and -not [string]::IsNullOrWhiteSpace($graphScopes)

    if (-not $integrationEnabled) {
        It 'is disabled until UTILITYBELT_ENTRA_TENANT_ID and UTILITYBELT_GRAPH_SCOPES are set' {
            $true | Should Be $true
        }
    }
    else {
        Import-Module "$PSScriptRoot\..\UtilityBelt.psd1" -Force

        It 'has an active Microsoft Graph connection to the configured lab tenant' {
            $context = Get-MgContext
            $requiredScopes = $graphScopes -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            $null -ne $context | Should Be $true
            $context.TenantId | Should Be $tenantId

            foreach ($scope in $requiredScopes) {
                $context.Scopes -contains $scope | Should Be $true
            }
        }

        It 'returns seeded cloud-only lab users' {
            $users = Get-EntraUserInventory -IncludeAll -PassThruOnly
            $activeUser = $users | Where-Object { $_.DisplayName -eq 'UB Lab Active User' }
            $disabledUser = $users | Where-Object { $_.DisplayName -eq 'UB Lab Disabled User' }
            $topUser = Get-EntraUserInventory -Top 1 -PassThruOnly

            @($topUser).Count | Should Be 1
            $activeUser.AccountEnabled | Should Be $true
            $disabledUser.AccountEnabled | Should Be $false
            $activeUser.Department | Should Be 'UtilityBelt Lab'
        }

        It 'returns seeded app registrations and service principals' {
            $applications = Get-EntraApplicationAudit -IncludeServicePrincipals -PassThruOnly
            $appWithoutCredential = $applications | Where-Object { $_.ObjectType -eq 'Application' -and $_.DisplayName -eq 'UB Lab App No Credential' }
            $appWithCredential = $applications | Where-Object { $_.ObjectType -eq 'Application' -and $_.DisplayName -eq 'UB Lab App With Credential' }
            $servicePrincipal = $applications | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.DisplayName -eq 'UB Lab App With Credential' }

            $appWithoutCredential.PasswordCredentialCount | Should Be 0
            $appWithCredential.HasCredentials | Should Be $true
            @($servicePrincipal).Count -ge 1 | Should Be $true
        }

        if ($env:UTILITYBELT_ENTRA_ENABLE_CA_TESTS -eq '1') {
            It 'returns and exports seeded Conditional Access policies' {
                $policies = Export-EntraConditionalAccessPolicy -PassThru
                $labPolicies = $policies | Where-Object { $_.DisplayName -like 'UB Lab CA *' }
                $outputPath = Join-Path -Path $TestDrive -ChildPath 'conditional-access-export.json'

                Export-EntraConditionalAccessPolicy -OutputPath $outputPath
                $exportedPolicies = Get-Content -Path $outputPath -Raw | ConvertFrom-Json

                @($labPolicies).Count -ge 2 | Should Be $true
                ($labPolicies | Where-Object { $_.State -in @('disabled', 'reportOnly', 'enabledForReportingButNotEnforced') }).Count -ge 2 | Should Be $true
                @($exportedPolicies).Count -ge @($policies).Count | Should Be $true
            }
        }
        else {
            It 'does not run Conditional Access integration tests unless explicitly enabled' {
                $true | Should Be $true
            }
        }
    }
}
