#requires -Version 7.2

# Internal helpers for the dot-sourced Entra commands. No connection is opened here.
function Import-EntraGraphModule {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    Import-Module -Name $Name -MinimumVersion 2.0.0 -ErrorAction Stop
}

function Write-EntraLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Information', 'Warning')][string]$Level = 'Information'
    )

    # Keep identifiers, request bodies, passwords and raw Graph responses out of logs.
    $entry = '{0:o} [{1}] {2}: {3}' -f [datetime]::UtcNow, $Level, $Operation, $Message
    if ($Level -eq 'Warning') { Write-Warning $entry }
    else { Write-Information -MessageData $entry -Tags 'Entra', $Operation }
}

function Assert-EntraGraphSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$TenantId,
        [Parameter(Mandatory)][string]$RequiredModule
    )

    $expectedTenant = [guid]::Empty
    if (-not [guid]::TryParse($TenantId, [ref]$expectedTenant) -or $expectedTenant -eq [guid]::Empty) {
        throw 'Provide a nonempty tenant GUID through -TenantId or ENTRA_TENANT_ID.'
    }
    Import-EntraGraphModule -Name 'Microsoft.Graph.Authentication'
    $context = Get-MgContext -ErrorAction Stop
    if (-not $context) { throw 'Connect first using Connect-EntraGraph.' }
    if ($context.AuthType -ne 'AppOnly' -or $context.ContextScope -ne 'Process' -or $context.Environment -ne 'Global') {
        throw 'An app-only Microsoft Graph Global connection with Process context scope is required.'
    }
    if ($context.TenantId -ne $expectedTenant.ToString()) {
        throw 'The active Graph connection does not match the expected lab tenant. Reconnect before continuing.'
    }
    Import-EntraGraphModule -Name $RequiredModule
    Write-Verbose 'Validated the app-only Graph session and expected lab tenant.'
}

function Assert-EntraCloudUser {
    [CmdletBinding()]
    param([Parameter(Mandatory)][guid]$UserId)

    $user = Get-MgUser -UserId $UserId.ToString() -Property @('id', 'userType', 'onPremisesSyncEnabled') -ErrorAction Stop
    if (-not $user -or $user.Id -ne $UserId.ToString() -or $user.UserType -ne 'Member' -or $user.OnPremisesSyncEnabled -eq $true) {
        throw 'This operation requires an existing cloud-only Member user. Synced users and guests are outside this lab workflow.'
    }
    return $user
}

function Assert-EntraStaticSecurityGroup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][guid]$GroupId)

    $group = Get-MgGroup -GroupId $GroupId.ToString() -Property @(
        'id', 'securityEnabled', 'mailEnabled', 'groupTypes', 'onPremisesSyncEnabled', 'isAssignableToRole'
    ) -ErrorAction Stop
    if (-not $group -or $group.Id -ne $GroupId.ToString() -or $group.SecurityEnabled -ne $true -or
        $group.MailEnabled -ne $false -or $group.OnPremisesSyncEnabled -eq $true -or
        $group.IsAssignableToRole -eq $true -or @($group.GroupTypes).Count -gt 0) {
        throw 'This workflow requires a cloud-only static security group without mail or role assignment. Dynamic, synced and role-assignable groups are excluded.'
    }
    return $group
}
