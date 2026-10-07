# Requires Pester 5. These tests use fabricated identifiers and mock every Graph command.
# No Microsoft Graph SDK installation, certificate, tenant, or network access is required.

Describe 'Entra lifecycle (offline)' -Tag 'Unit', 'Entra' {
    BeforeAll {
        $script:TenantId = '11111111-1111-4111-8111-111111111111'
        $script:ClientId = '22222222-2222-4222-8222-222222222222'
        $script:UserId = '33333333-3333-4333-8333-333333333333'
        $script:GroupId = '44444444-4444-4444-8444-444444444444'
        $script:OtherTenantId = '55555555-5555-4555-8555-555555555555'
        $script:LabPassword = 'Contoso-Offline-' + [guid]::NewGuid().ToString('N') + '!42'
        $script:CertificateKey = [System.Security.Cryptography.RSA]::Create(2048)
        $script:CertificateRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            'CN=Contoso Offline Test', $script:CertificateKey,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        $script:LabCertificate = $script:CertificateRequest.CreateSelfSigned([datetimeoffset]::UtcNow.AddDays(-1), [datetimeoffset]::UtcNow.AddDays(1))
        $script:Thumbprint = $script:LabCertificate.Thumbprint
        $script:SavedEnvironment = @{}
        foreach ($name in 'ENTRA_TENANT_ID', 'ENTRA_CLIENT_ID', 'ENTRA_CERTIFICATE_THUMBPRINT') {
            $script:SavedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }

        # Define SDK-shaped commands only if the installed SDK has not already exposed them.
        # Advanced functions give Pester realistic parameter binding, including ErrorAction.
        $stubs = @{
            'Get-MgContext' = '[CmdletBinding()] param() throw "Unmocked Graph context access."'
            'Connect-MgGraph' = '[CmdletBinding()] param([string]$TenantId, [string]$ClientId, [string]$CertificateThumbprint, [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate, [string]$ContextScope, [string]$Environment, [switch]$NoWelcome) throw "Unmocked Graph connection."'
            'Disconnect-MgGraph' = '[CmdletBinding()] param() throw "Unmocked Graph disconnection."'
            'Get-MgUser' = '[CmdletBinding()] param([string]$UserId, [switch]$All, [int]$Top, [string]$Filter, [string[]]$Property, [string]$ConsistencyLevel, [string]$CountVariable) throw "Unmocked Graph user read."'
            'New-MgUser' = '[CmdletBinding(SupportsShouldProcess)] param([System.Collections.IDictionary]$BodyParameter) throw "Unmocked Graph user creation."'
            'Update-MgUser' = '[CmdletBinding(SupportsShouldProcess)] param([string]$UserId, [System.Collections.IDictionary]$BodyParameter) throw "Unmocked Graph user update."'
            'Remove-MgUser' = '[CmdletBinding(SupportsShouldProcess)] param([string]$UserId) throw "Unmocked Graph user deletion."'
            'Get-MgDirectoryDeletedItemAsUser' = '[CmdletBinding()] param([string]$DirectoryObjectId, [switch]$All, [int]$Top, [string]$Filter, [string[]]$Property, [System.Collections.IDictionary]$Headers, [string]$CountVariable) throw "Unmocked Graph deleted-user read."'
            'Restore-MgDirectoryDeletedItem' = '[CmdletBinding(SupportsShouldProcess)] param([string]$DirectoryObjectId) throw "Unmocked Graph user restoration."'
            'Get-MgGroup' = '[CmdletBinding()] param([string]$GroupId, [string[]]$Property) throw "Unmocked Graph group read."'
            'New-MgGroup' = '[CmdletBinding(SupportsShouldProcess)] param([System.Collections.IDictionary]$BodyParameter) throw "Unmocked Graph group creation."'
            'New-MgGroupMemberByRef' = '[CmdletBinding(SupportsShouldProcess)] param([string]$GroupId, [System.Collections.IDictionary]$BodyParameter) throw "Unmocked Graph membership creation."'
            'Remove-MgGroupMemberDirectoryObjectByRef' = '[CmdletBinding(SupportsShouldProcess)] param([string]$GroupId, [string]$DirectoryObjectId) throw "Unmocked Graph membership removal."'
            'Get-MgGroupMember' = '[CmdletBinding()] param([string]$GroupId, [switch]$All, [int]$Top, [string[]]$Property) throw "Unmocked Graph membership read."'
        }
        foreach ($name in $stubs.Keys) {
            if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) {
                Set-Item -Path "Function:$name" -Value ([scriptblock]::Create($stubs[$name]))
            }
        }

        $script:FunctionNames = @(
            'Connect-EntraGraph', 'Get-EntraUser', 'New-EntraUser', 'Disable-EntraUser',
            'Get-EntraDeletedUser', 'Restore-EntraUser', 'Remove-EntraUser',
            'New-EntraSecurityGroup', 'Add-EntraGroupMember', 'Remove-EntraGroupMember',
            'Get-EntraGroupMember'
        )
        foreach ($name in $script:FunctionNames) {
            . (Join-Path $PSScriptRoot "../src/Identity/Entra/$name.ps1")
        }

        function New-LabUser {
            [pscustomobject]@{
                Id = $script:UserId
                DisplayName = 'Contoso Lab User'
                UserPrincipalName = 'lab.user@contoso.onmicrosoft.com'
                UserType = 'Member'
                AccountEnabled = $true
                OnPremisesSyncEnabled = $false
            }
        }

        function New-LabGroup {
            [pscustomobject]@{
                Id = $script:GroupId
                DisplayName = 'Contoso Lab Security Group'
                SecurityEnabled = $true
                MailEnabled = $false
                GroupTypes = @()
                OnPremisesSyncEnabled = $false
                IsAssignableToRole = $false
            }
        }

        function Get-LabMutationArguments {
            param([string]$Name)
            $arguments = @{ TenantId = $script:TenantId }
            switch ($Name) {
                'New-EntraUser' {
                    $arguments.DisplayName = 'Contoso Lab User'
                    $arguments.UserPrincipalName = 'lab.user@contoso.onmicrosoft.com'
                    $arguments.MailNickname = 'lab.user'
                    $arguments.Password = ConvertTo-SecureString $script:LabPassword -AsPlainText -Force
                }
                'New-EntraSecurityGroup' {
                    $arguments.DisplayName = 'Contoso Lab Security Group'
                    $arguments.MailNickname = 'contoso-lab-security'
                    $arguments.OwnerUserId = $script:UserId
                }
                default { $arguments.UserId = $script:UserId }
            }
            if ($Name -in 'Add-EntraGroupMember', 'Remove-EntraGroupMember') {
                $arguments.GroupId = $script:GroupId
            }
            $arguments
        }
    }

    BeforeEach {
        [Environment]::SetEnvironmentVariable('ENTRA_TENANT_ID', $null, 'Process')
        [Environment]::SetEnvironmentVariable('ENTRA_CLIENT_ID', $null, 'Process')
        [Environment]::SetEnvironmentVariable('ENTRA_CERTIFICATE_THUMBPRINT', $null, 'Process')
        Mock Import-EntraGraphModule {}
        Mock Get-MgContext {
            [pscustomobject]@{
                TenantId = $script:TenantId
                ClientId = $script:ClientId
                AuthType = 'AppOnly'
                ContextScope = 'Process'
                Environment = 'Global'
            }
        }
        Mock Connect-MgGraph {}
        Mock Disconnect-MgGraph {}
        Mock Get-Item { $script:LabCertificate } -ParameterFilter { $LiteralPath -like 'Cert:\*' }
        Mock Get-MgUser { New-LabUser }
        Mock Get-MgDirectoryDeletedItemAsUser { New-LabUser }
        Mock Get-MgGroup { New-LabGroup }
        Mock Get-MgGroupMember { [pscustomobject]@{ Id = $script:UserId } }
        Mock New-MgUser {
            # The production function clears its request dictionary in finally. Capture
            # values while the mocked SDK is called, rather than inspect cleared history.
            $script:CreatedUserBody = @{
                displayName = $BodyParameter.displayName
                userPrincipalName = $BodyParameter.userPrincipalName
                mailNickname = $BodyParameter.mailNickname
                accountEnabled = $BodyParameter.accountEnabled
                userType = $BodyParameter.userType
                passwordProfile = @{
                    password = $BodyParameter.passwordProfile.password
                    forceChangePasswordNextSignIn = $BodyParameter.passwordProfile.forceChangePasswordNextSignIn
                }
            }
            New-LabUser
        }
        Mock Update-MgUser {}
        Mock Remove-MgUser {}
        Mock Restore-MgDirectoryDeletedItem { New-LabUser }
        Mock New-MgGroup { New-LabGroup }
        Mock New-MgGroupMemberByRef {}
        Mock Remove-MgGroupMemberDirectoryObjectByRef {}
    }

    AfterAll {
        foreach ($name in $script:SavedEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $script:SavedEnvironment[$name], 'Process')
        }
        $script:LabCertificate.Dispose()
        $script:CertificateKey.Dispose()
    }

    Describe 'Certificate application authentication' -Tag 'Unit', 'Entra' {
        It 'forwards explicit identifiers and uses a process-scoped public-cloud context' {
            Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -CertificateThumbprint $script:Thumbprint

            Should -Invoke Connect-MgGraph -Exactly -Times 1 -ParameterFilter {
                $TenantId -eq $script:TenantId -and $ClientId -eq $script:ClientId -and
                $Certificate.Thumbprint -eq $script:Thumbprint -and $ContextScope -eq 'Process' -and
                $Environment -eq 'Global' -and $NoWelcome -and $ErrorAction -eq 'Stop'
            }
            Should -Invoke Get-Item -Exactly -Times 1 -ParameterFilter {
                $LiteralPath -eq "Cert:\CurrentUser\My\$script:Thumbprint" -and $ErrorAction -eq 'Stop'
            }
        }

        It 'resolves certificate authentication identifiers from the process environment' {
            $env:ENTRA_TENANT_ID = $script:TenantId
            $env:ENTRA_CLIENT_ID = $script:ClientId
            $env:ENTRA_CERTIFICATE_THUMBPRINT = $script:Thumbprint

            Connect-EntraGraph

            Should -Invoke Connect-MgGraph -Exactly -Times 1 -ParameterFilter {
                $TenantId -eq $script:TenantId -and $ClientId -eq $script:ClientId -and
                $Certificate.Thumbprint -eq $script:Thumbprint
            }
        }

        It 'rejects missing authentication configuration without connecting' {
            { Connect-EntraGraph } | Should -Throw
            Should -Invoke Connect-MgGraph -Exactly -Times 0
        }

        It 'accepts a valid certificate object without using a certificate store' {
            Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -Certificate $script:LabCertificate
            Should -Invoke Connect-MgGraph -Exactly -Times 1 -ParameterFilter {
                $Certificate -eq $script:LabCertificate -and -not $CertificateThumbprint
            }
            Should -Invoke Get-Item -Exactly -Times 0 -ParameterFilter { $LiteralPath -like 'Cert:\*' }
        }

        It 'resolves an explicitly selected LocalMachine certificate store' {
            Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -CertificateThumbprint $script:Thumbprint -CertificateStore LocalMachine
            Should -Invoke Get-Item -Exactly -Times 1 -ParameterFilter {
                $LiteralPath -eq "Cert:\LocalMachine\My\$script:Thumbprint"
            }
            Should -Invoke Connect-MgGraph -Exactly -Times 1
        }

        It 'rejects a certificate without a private key' {
            $publicCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $script:LabCertificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            )
            try {
                { Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -Certificate $publicCertificate } | Should -Throw
                Should -Invoke Connect-MgGraph -Exactly -Times 0
            }
            finally { $publicCertificate.Dispose() }
        }

        It 'rejects a <Condition> certificate before connecting' -TestCases @(
            @{ Condition = 'expired'; StartDays = -2; EndDays = -1 }
            @{ Condition = 'not-yet-valid'; StartDays = 1; EndDays = 2 }
        ) {
            param($Condition, $StartDays, $EndDays)
            $certificate = $script:CertificateRequest.CreateSelfSigned(
                [datetimeoffset]::UtcNow.AddDays($StartDays), [datetimeoffset]::UtcNow.AddDays($EndDays)
            )
            try {
                { Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -Certificate $certificate } | Should -Throw
                Should -Invoke Connect-MgGraph -Exactly -Times 0
            }
            finally { $certificate.Dispose() }
        }

        It 'rejects a certificate-store result that does not match the requested thumbprint' {
            { Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -CertificateThumbprint ('B' * 40) } | Should -Throw
            Should -Invoke Connect-MgGraph -Exactly -Times 0
        }

        It 'rejects a resulting connection to a different application' {
            Mock Get-MgContext {
                [pscustomobject]@{
                    TenantId = $script:TenantId; ClientId = $script:OtherTenantId
                    AuthType = 'AppOnly'; ContextScope = 'Process'; Environment = 'Global'
                }
            }
            { Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -Certificate $script:LabCertificate } | Should -Throw
            Should -Invoke Connect-MgGraph -Exactly -Times 1
        }

        It 'rejects malformed <Parameter> without connecting' -TestCases @(
            @{ Parameter = 'TenantId' }, @{ Parameter = 'ClientId' }
        ) {
            param($Parameter)
            $arguments = @{
                TenantId = $script:TenantId
                ClientId = $script:ClientId
                CertificateThumbprint = $script:Thumbprint
            }
            $arguments[$Parameter] = 'not-a-guid'
            { Connect-EntraGraph @arguments } | Should -Throw
            Should -Invoke Connect-MgGraph -Exactly -Times 0
        }

        It 'surfaces certificate authentication errors' {
            Mock Connect-MgGraph { throw 'Simulated certificate authentication failure.' }
            { Connect-EntraGraph -TenantId $script:TenantId -ClientId $script:ClientId -CertificateThumbprint $script:Thumbprint } |
                Should -Throw '*Simulated certificate authentication failure*'
        }
    }

    Describe 'Tenant and session boundaries' -Tag 'Unit', 'Entra' {
        It 'rejects a missing expected tenant before a user read' {
            { Get-EntraUser } | Should -Throw
            Should -Invoke Get-MgUser -Exactly -Times 0
        }

        It 'reads the expected tenant from the process environment' {
            $env:ENTRA_TENANT_ID = $script:TenantId
            Get-EntraUser | Out-Null
            Should -Invoke Get-MgUser -Exactly -Times 1
        }

        It 'rejects a malformed expected tenant before a user read' {
            { Get-EntraUser -TenantId 'not-a-guid' } | Should -Throw
            Should -Invoke Get-MgUser -Exactly -Times 0
        }

        It 'rejects an absent Graph session' {
            Mock Get-MgContext { $null }
            { Get-EntraUser -TenantId $script:TenantId } | Should -Throw
            Should -Invoke Get-MgUser -Exactly -Times 0
        }

        It 'rejects a session with an unsafe <Field>' -TestCases @(
            @{ Field = 'TenantId'; Value = '55555555-5555-4555-8555-555555555555' }
            @{ Field = 'AuthType'; Value = 'Delegated' }
            @{ Field = 'ContextScope'; Value = 'CurrentUser' }
            @{ Field = 'Environment'; Value = 'China' }
        ) {
            param($Field, $Value)
            $script:UnsafeContextField = $Field
            $script:UnsafeContextValue = $Value
            Mock Get-MgContext {
                $context = [pscustomobject]@{
                    TenantId = $script:TenantId; AuthType = 'AppOnly'; ContextScope = 'Process'; Environment = 'Global'
                }
                $context.($script:UnsafeContextField) = $script:UnsafeContextValue
                $context
            }

            { Get-EntraUser -TenantId $script:TenantId } | Should -Throw
            Should -Invoke Get-MgUser -Exactly -Times 0
        }
    }

    Describe 'User and membership reads' -Tag 'Unit', 'Entra' {
        It 'requests all user pages by default' {
            $result = Get-EntraUser -TenantId $script:TenantId
            $result.Id | Should -Be $script:UserId
            Should -Invoke Get-MgUser -Exactly -Times 1 -ParameterFilter { $All -and $ErrorAction -eq 'Stop' }
        }

        It 'forwards a user filter and keeps automatic pagination' {
            Get-EntraUser -TenantId $script:TenantId -Filter "startsWith(displayName,'Contoso Lab')" | Out-Null
            Should -Invoke Get-MgUser -Exactly -Times 1 -ParameterFilter {
                $All -and $Filter -eq "startsWith(displayName,'Contoso Lab')" -and
                $ConsistencyLevel -eq 'eventual' -and $CountVariable -eq 'entraUserCount'
            }
        }

        It 'forwards an explicit user limit without requesting all pages' {
            Get-EntraUser -TenantId $script:TenantId -Top 2 | Out-Null
            Should -Invoke Get-MgUser -Exactly -Times 1 -ParameterFilter { $Top -eq 2 -and -not $All }
        }

        It 'requests a single user by immutable object identifier' {
            Get-EntraUser -TenantId $script:TenantId -UserId $script:UserId | Out-Null
            Should -Invoke Get-MgUser -Exactly -Times 1 -ParameterFilter { $UserId -eq $script:UserId -and -not $All }
        }

        It 'rejects a malformed user identifier before querying Graph' {
            { Get-EntraUser -TenantId $script:TenantId -UserId 'not-a-guid' } | Should -Throw
            Should -Invoke Get-MgUser -Exactly -Times 0
        }

        It 'uses the typed deleted-user endpoint and requests all pages by default' {
            $result = Get-EntraDeletedUser -TenantId $script:TenantId
            $result.Id | Should -Be $script:UserId
            Should -Invoke Get-MgDirectoryDeletedItemAsUser -Exactly -Times 1 -ParameterFilter { $All -and $ErrorAction -eq 'Stop' }
        }

        It 'forwards a deleted-user filter with automatic pagination' {
            Get-EntraDeletedUser -TenantId $script:TenantId -Filter "displayName eq 'Contoso Lab User'" | Out-Null
            Should -Invoke Get-MgDirectoryDeletedItemAsUser -Exactly -Times 1 -ParameterFilter {
                $All -and $Filter -eq "displayName eq 'Contoso Lab User'" -and
                $Headers.ConsistencyLevel -eq 'eventual' -and $CountVariable -eq 'entraDeletedUserCount'
            }
        }

        It 'forwards an explicit deleted-user limit without requesting all pages' {
            Get-EntraDeletedUser -TenantId $script:TenantId -Top 2 | Out-Null
            Should -Invoke Get-MgDirectoryDeletedItemAsUser -Exactly -Times 1 -ParameterFilter { $Top -eq 2 -and -not $All }
        }

        It 'requests all direct membership pages' {
            $result = Get-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId
            $result.Id | Should -Be $script:UserId
            Should -Invoke Get-MgGroupMember -Exactly -Times 1 -ParameterFilter {
                $GroupId -eq $script:GroupId -and $All -and $ErrorAction -eq 'Stop'
            }
        }

        It 'requests a single deleted user by immutable object identifier' {
            Get-EntraDeletedUser -TenantId $script:TenantId -UserId $script:UserId | Out-Null
            Should -Invoke Get-MgDirectoryDeletedItemAsUser -Exactly -Times 1 -ParameterFilter {
                $DirectoryObjectId -eq $script:UserId -and -not $All
            }
        }

        It 'forwards an explicit membership limit without requesting all pages' {
            Get-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId -Top 2 | Out-Null
            Should -Invoke Get-MgGroupMember -Exactly -Times 1 -ParameterFilter {
                $GroupId -eq $script:GroupId -and $Top -eq 2 -and -not $All
            }
        }

        It 'surfaces a user read failure' {
            Mock Get-MgUser { throw 'Simulated user read failure.' }
            { Get-EntraUser -TenantId $script:TenantId } | Should -Throw '*Simulated user read failure*'
        }

        It 'surfaces a deleted-user read failure' {
            Mock Get-MgDirectoryDeletedItemAsUser { throw 'Simulated deleted-user read failure.' }
            { Get-EntraDeletedUser -TenantId $script:TenantId } | Should -Throw '*Simulated deleted-user read failure*'
        }

        It 'surfaces a membership read failure' {
            Mock Get-MgGroupMember { throw 'Simulated membership read failure.' }
            { Get-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId } |
                Should -Throw '*Simulated membership read failure*'
        }
    }

    Describe 'Mutation safeguards' -Tag 'Unit', 'Entra' {
        It '<Name> honors WhatIf without any SDK write' -TestCases @(
            @{ Name = 'New-EntraUser' }, @{ Name = 'Disable-EntraUser' },
            @{ Name = 'Restore-EntraUser' }, @{ Name = 'Remove-EntraUser' },
            @{ Name = 'New-EntraSecurityGroup' }, @{ Name = 'Add-EntraGroupMember' },
            @{ Name = 'Remove-EntraGroupMember' }
        ) {
            param($Name)
            $arguments = Get-LabMutationArguments -Name $Name
            & $Name @arguments -WhatIf

            foreach ($command in 'New-MgUser', 'Update-MgUser', 'Remove-MgUser', 'Restore-MgDirectoryDeletedItem',
                'New-MgGroup', 'New-MgGroupMemberByRef', 'Remove-MgGroupMemberDirectoryObjectByRef') {
                Should -Invoke $command -Exactly -Times 0
            }
            (Get-Command $Name).Parameters.ContainsKey('Confirm') | Should -BeTrue
        }

        It '<Name> rejects an unexpected tenant without an SDK write' -TestCases @(
            @{ Name = 'New-EntraUser'; WriteCommand = 'New-MgUser' }
            @{ Name = 'Disable-EntraUser'; WriteCommand = 'Update-MgUser' }
            @{ Name = 'Restore-EntraUser'; WriteCommand = 'Restore-MgDirectoryDeletedItem' }
            @{ Name = 'Remove-EntraUser'; WriteCommand = 'Remove-MgUser' }
            @{ Name = 'New-EntraSecurityGroup'; WriteCommand = 'New-MgGroup' }
            @{ Name = 'Add-EntraGroupMember'; WriteCommand = 'New-MgGroupMemberByRef' }
            @{ Name = 'Remove-EntraGroupMember'; WriteCommand = 'Remove-MgGroupMemberDirectoryObjectByRef' }
        ) {
            param($Name, $WriteCommand)
            $arguments = Get-LabMutationArguments -Name $Name
            $arguments.TenantId = $script:OtherTenantId
            { & $Name @arguments -Confirm:$false } | Should -Throw
            Should -Invoke $WriteCommand -Exactly -Times 0
        }

        It '<Name> surfaces an SDK write failure' -TestCases @(
            @{ Name = 'New-EntraUser'; WriteCommand = 'New-MgUser' }
            @{ Name = 'Disable-EntraUser'; WriteCommand = 'Update-MgUser' }
            @{ Name = 'Restore-EntraUser'; WriteCommand = 'Restore-MgDirectoryDeletedItem' }
            @{ Name = 'Remove-EntraUser'; WriteCommand = 'Remove-MgUser' }
            @{ Name = 'New-EntraSecurityGroup'; WriteCommand = 'New-MgGroup' }
            @{ Name = 'Add-EntraGroupMember'; WriteCommand = 'New-MgGroupMemberByRef' }
            @{ Name = 'Remove-EntraGroupMember'; WriteCommand = 'Remove-MgGroupMemberDirectoryObjectByRef' }
        ) {
            param($Name, $WriteCommand)
            Mock $WriteCommand { throw 'Simulated Graph write failure.' }
            $arguments = Get-LabMutationArguments -Name $Name
            { & $Name @arguments -Confirm:$false } | Should -Throw '*Simulated Graph write failure*'
            Should -Invoke $WriteCommand -Exactly -Times 1
        }

        It '<Name> rejects an invalid <Parameter>' -TestCases @(
            @{ Name = 'Disable-EntraUser'; Parameter = 'UserId'; WriteCommand = 'Update-MgUser' }
            @{ Name = 'Restore-EntraUser'; Parameter = 'UserId'; WriteCommand = 'Restore-MgDirectoryDeletedItem' }
            @{ Name = 'Remove-EntraUser'; Parameter = 'UserId'; WriteCommand = 'Remove-MgUser' }
            @{ Name = 'New-EntraSecurityGroup'; Parameter = 'OwnerUserId'; WriteCommand = 'New-MgGroup' }
            @{ Name = 'Add-EntraGroupMember'; Parameter = 'UserId'; WriteCommand = 'New-MgGroupMemberByRef' }
            @{ Name = 'Add-EntraGroupMember'; Parameter = 'GroupId'; WriteCommand = 'New-MgGroupMemberByRef' }
            @{ Name = 'Remove-EntraGroupMember'; Parameter = 'UserId'; WriteCommand = 'Remove-MgGroupMemberDirectoryObjectByRef' }
            @{ Name = 'Remove-EntraGroupMember'; Parameter = 'GroupId'; WriteCommand = 'Remove-MgGroupMemberDirectoryObjectByRef' }
        ) {
            param($Name, $Parameter, $WriteCommand)
            $arguments = Get-LabMutationArguments -Name $Name
            $arguments[$Parameter] = 'not-a-guid'
            { & $Name @arguments -Confirm:$false } | Should -Throw
            Should -Invoke $WriteCommand -Exactly -Times 0
        }
    }

    Describe 'Safe mutation payloads' -Tag 'Unit', 'Entra' {
        It 'creates users disabled by default and requires a password change at first sign-in' {
            $arguments = Get-LabMutationArguments -Name 'New-EntraUser'
            New-EntraUser @arguments -Confirm:$false | Out-Null

            Should -Invoke New-MgUser -Exactly -Times 1 -ParameterFilter { $ErrorAction -eq 'Stop' -and -not $Confirm }
            $script:CreatedUserBody.displayName | Should -Be 'Contoso Lab User'
            $script:CreatedUserBody.userPrincipalName | Should -Be 'lab.user@contoso.onmicrosoft.com'
            $script:CreatedUserBody.mailNickname | Should -Be 'lab.user'
            $script:CreatedUserBody.accountEnabled | Should -BeFalse
            $script:CreatedUserBody.userType | Should -Be 'Member'
            $script:CreatedUserBody.passwordProfile.forceChangePasswordNextSignIn | Should -BeTrue
            $script:CreatedUserBody.passwordProfile.password | Should -Be $script:LabPassword
        }

        It 'enables a new user only when explicitly requested' {
            $arguments = Get-LabMutationArguments -Name 'New-EntraUser'
            New-EntraUser @arguments -Enabled -Confirm:$false | Out-Null
            Should -Invoke New-MgUser -Exactly -Times 1
            $script:CreatedUserBody.accountEnabled | Should -BeTrue
        }

        It 'keeps the plaintext password out of informational and verbose output' {
            $arguments = Get-LabMutationArguments -Name 'New-EntraUser'
            $output = New-EntraUser @arguments -Confirm:$false -Verbose -InformationAction Continue 4>&1 6>&1 | Out-String
            $output | Should -Not -Match ([regex]::Escape($script:LabPassword))
        }

        It 'disables only the requested cloud user' {
            Disable-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false
            Should -Invoke Update-MgUser -Exactly -Times 1 -ParameterFilter {
                $UserId -eq $script:UserId -and $BodyParameter.accountEnabled -eq $false -and
                $BodyParameter.Keys.Count -eq 1 -and $ErrorAction -eq 'Stop'
            }
        }

        It 'soft deletes only the requested cloud user' {
            Remove-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false
            Should -Invoke Remove-MgUser -Exactly -Times 1 -ParameterFilter {
                $UserId -eq $script:UserId -and $ErrorAction -eq 'Stop'
            }
        }

        It 'preflights restoration through the typed deleted-user endpoint' {
            Restore-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false | Out-Null
            Should -Invoke Get-MgDirectoryDeletedItemAsUser -Exactly -Times 1 -ParameterFilter {
                $DirectoryObjectId -eq $script:UserId -and $ErrorAction -eq 'Stop'
            }
            Should -Invoke Restore-MgDirectoryDeletedItem -Exactly -Times 1 -ParameterFilter {
                $DirectoryObjectId -eq $script:UserId -and $ErrorAction -eq 'Stop'
            }
        }

        It 'does not restore an object when the deleted-user preflight fails' {
            Mock Get-MgDirectoryDeletedItemAsUser { throw 'Deleted object is not a user.' }
            { Restore-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke Restore-MgDirectoryDeletedItem -Exactly -Times 0
        }

        It 'creates a static non-mail security group with an explicit owner' {
            $arguments = Get-LabMutationArguments -Name 'New-EntraSecurityGroup'
            New-EntraSecurityGroup @arguments -Confirm:$false | Out-Null
            Should -Invoke New-MgGroup -Exactly -Times 1 -ParameterFilter {
                $BodyParameter.displayName -eq 'Contoso Lab Security Group' -and
                $BodyParameter.mailNickname -eq 'contoso-lab-security' -and
                $BodyParameter.securityEnabled -eq $true -and $BodyParameter.mailEnabled -eq $false -and
                @($BodyParameter.groupTypes).Count -eq 0 -and
                -not $BodyParameter.Contains('isAssignableToRole') -and
                @($BodyParameter.'owners@odata.bind').Count -eq 1 -and
                $BodyParameter.'owners@odata.bind'[0] -eq "https://graph.microsoft.com/v1.0/users/$script:UserId" -and
                $ErrorAction -eq 'Stop'
            }
        }

        It 'adds exactly one user through the membership reference endpoint' {
            Add-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId -UserId $script:UserId -Confirm:$false
            Should -Invoke New-MgGroupMemberByRef -Exactly -Times 1 -ParameterFilter {
                $GroupId -eq $script:GroupId -and
                $BodyParameter.'@odata.id' -eq "https://graph.microsoft.com/v1.0/directoryObjects/$script:UserId" -and
                $BodyParameter.Keys.Count -eq 1 -and $ErrorAction -eq 'Stop'
            }
        }

        It 'removes only the membership reference without deleting the user' {
            Remove-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId -UserId $script:UserId -Confirm:$false
            Should -Invoke Remove-MgGroupMemberDirectoryObjectByRef -Exactly -Times 1 -ParameterFilter {
                $GroupId -eq $script:GroupId -and $DirectoryObjectId -eq $script:UserId -and $ErrorAction -eq 'Stop'
            }
            Should -Invoke Remove-MgUser -Exactly -Times 0
        }
    }

    Describe 'Cloud-only user and static security-group preflights' -Tag 'Unit', 'Entra' {
        It 'rejects a user preflight returning a different object identifier' {
            Mock Get-MgUser {
                $user = New-LabUser
                $user.Id = $script:OtherTenantId
                $user
            }
            { Disable-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke Update-MgUser -Exactly -Times 0
        }

        It 'rejects a deleted-user preflight returning a different object identifier' {
            Mock Get-MgDirectoryDeletedItemAsUser {
                $user = New-LabUser
                $user.Id = $script:OtherTenantId
                $user
            }
            { Restore-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke Restore-MgDirectoryDeletedItem -Exactly -Times 0
        }

        It 'rejects a group preflight returning a different object identifier' {
            Mock Get-MgGroup {
                $group = New-LabGroup
                $group.Id = $script:OtherTenantId
                $group
            }
            { Add-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke New-MgGroupMemberByRef -Exactly -Times 0
        }

        It 'accepts ordinary cloud group properties that Graph represents as null' {
            Mock Get-MgGroup {
                $group = New-LabGroup
                $group.OnPremisesSyncEnabled = $null
                $group.IsAssignableToRole = $null
                $group
            }
            Get-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId | Out-Null
            Should -Invoke Get-MgGroupMember -Exactly -Times 1
        }

        It 'rejects a <Condition> user before disabling it' -TestCases @(
            @{ Condition = 'synchronized'; Property = 'OnPremisesSyncEnabled'; Value = $true }
            @{ Condition = 'guest'; Property = 'UserType'; Value = 'Guest' }
        ) {
            param($Condition, $Property, $Value)
            $script:UnsafeUserProperty = $Property
            $script:UnsafeUserValue = $Value
            Mock Get-MgUser {
                $user = New-LabUser
                $user.($script:UnsafeUserProperty) = $script:UnsafeUserValue
                $user
            }
            { Disable-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke Update-MgUser -Exactly -Times 0
        }

        It 'rejects a synchronized user before soft deletion' {
            Mock Get-MgUser {
                $user = New-LabUser
                $user.OnPremisesSyncEnabled = $true
                $user
            }
            { Remove-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke Remove-MgUser -Exactly -Times 0
        }

        It 'rejects a <Condition> deleted user before restoration' -TestCases @(
            @{ Condition = 'synchronized'; Property = 'OnPremisesSyncEnabled'; Value = $true }
            @{ Condition = 'guest'; Property = 'UserType'; Value = 'Guest' }
        ) {
            param($Condition, $Property, $Value)
            $script:UnsafeDeletedUserProperty = $Property
            $script:UnsafeDeletedUserValue = $Value
            Mock Get-MgDirectoryDeletedItemAsUser {
                $user = New-LabUser
                $user.($script:UnsafeDeletedUserProperty) = $script:UnsafeDeletedUserValue
                $user
            }
            { Restore-EntraUser -TenantId $script:TenantId -UserId $script:UserId -Confirm:$false } | Should -Throw
            Should -Invoke Restore-MgDirectoryDeletedItem -Exactly -Times 0
        }

        It 'rejects a <Condition> group before adding a member' -TestCases @(
            @{ Condition = 'dynamic'; Property = 'GroupTypes'; Value = @('DynamicMembership') }
            @{ Condition = 'mail-enabled'; Property = 'MailEnabled'; Value = $true }
            @{ Condition = 'non-security'; Property = 'SecurityEnabled'; Value = $false }
            @{ Condition = 'synchronized'; Property = 'OnPremisesSyncEnabled'; Value = $true }
            @{ Condition = 'role-assignable'; Property = 'IsAssignableToRole'; Value = $true }
        ) {
            param($Condition, $Property, $Value)
            $script:UnsafeGroupProperty = $Property
            $script:UnsafeGroupValue = $Value
            Mock Get-MgGroup {
                $group = New-LabGroup
                $group.($script:UnsafeGroupProperty) = $script:UnsafeGroupValue
                $group
            }
            { Add-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId -UserId $script:UserId -Confirm:$false } |
                Should -Throw
            Should -Invoke New-MgGroupMemberByRef -Exactly -Times 0
        }

        It 'rejects a role-assignable group before removing a member' {
            Mock Get-MgGroup {
                $group = New-LabGroup
                $group.IsAssignableToRole = $true
                $group
            }
            { Remove-EntraGroupMember -TenantId $script:TenantId -GroupId $script:GroupId -UserId $script:UserId -Confirm:$false } |
                Should -Throw
            Should -Invoke Remove-MgGroupMemberDirectoryObjectByRef -Exactly -Times 0
        }

        It 'does not create a group with a guest owner' {
            Mock Get-MgUser {
                $user = New-LabUser
                $user.UserType = 'Guest'
                $user
            }
            $arguments = Get-LabMutationArguments -Name 'New-EntraSecurityGroup'
            { New-EntraSecurityGroup @arguments -Confirm:$false } | Should -Throw
            Should -Invoke New-MgGroup -Exactly -Times 0
        }
    }
}
