#requires -Version 7.2
. (Join-Path -Path $PSScriptRoot -ChildPath 'Private/Entra.Common.ps1')

function New-EntraSecurityGroup {
    <#
    .SYNOPSIS
    Creates a cloud-only, static Entra security group in the connected lab tenant.
    .DESCRIPTION
    Uses Microsoft Graph application authentication to create a non-mail-enabled,
    non-role-assignable security group with an explicitly supplied cloud-only
    member user as its owner. Requires Group.Create and User.Read.All application
    permissions and administrator consent. User.Read.All supports owner binding
    and the lab-safety preflight check.
    The connected tenant must match TenantId. Run Connect-EntraGraph first.
    .PARAMETER DisplayName
    The group display name, between 1 and 256 characters.
    .PARAMETER MailNickname
    A unique lab alias, up to 64 letters, digits, periods, underscores, or hyphens.
    An alias is required by Graph even though the group is not mail-enabled.
    .PARAMETER Description
    An optional description of the group's purpose.
    .PARAMETER OwnerUserId
    The object ID of the existing cloud-only lab member user who will own the
    group. An explicit owner prevents an anonymously created, unmanageable group.
    .PARAMETER TenantId
    The expected lab tenant ID. Defaults to ENTRA_TENANT_ID.
    .EXAMPLE
    $owner = Get-EntraUser -Filter "displayName eq 'Contoso Lab Owner'"
    New-EntraSecurityGroup -DisplayName 'Contoso Lab Readers' -MailNickname 'contoso-lab-readers' -OwnerUserId $owner.Id -Description 'Contoso IAM portfolio lab' -WhatIf
    Previews creation of a lab security group without changing the tenant.
    .EXAMPLE
    $group = New-EntraSecurityGroup -DisplayName 'Contoso Lab Readers' -MailNickname 'contoso-lab-readers' -OwnerUserId $owner.Id -Confirm
    Creates a lab security group after confirmation and returns the Graph group.
    .OUTPUTS
    Microsoft.Graph.PowerShell.Models.IMicrosoftGraphGroup
    .NOTES
    Requires PowerShell 7.2+, Microsoft.Graph.Authentication, and
    Microsoft.Graph.Groups, and Microsoft.Graph.Users. Use a dedicated lab app
    with admin consent.
    Group.Create grants creation rights; separate least-privilege permissions
    are required for subsequent membership administration.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 256)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
        [string]$MailNickname,

        [Parameter()]
        [ValidateLength(0, 1024)]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$OwnerUserId,

        [Parameter()]
        [string]$TenantId = $env:ENTRA_TENANT_ID
    )

    process {
        try {
            Write-EntraLog -Operation 'New-EntraSecurityGroup' -Message 'Starting security group creation.' -Level Information
            Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Groups'
            Import-EntraGraphModule -Name 'Microsoft.Graph.Users'
            $null = Assert-EntraCloudUser -UserId $OwnerUserId

            $body = @{
                displayName        = $DisplayName
                mailNickname       = $MailNickname
                mailEnabled        = $false
                securityEnabled    = $true
                groupTypes         = @()
                'owners@odata.bind' = @("https://graph.microsoft.com/v1.0/users/$OwnerUserId")
            }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $body['description'] = $Description
            }

            if ($PSCmdlet.ShouldProcess($DisplayName, 'Create a static Entra security group')) {
                $group = New-MgGroup -BodyParameter $body -Confirm:$false -ErrorAction Stop
                Write-EntraLog -Operation 'New-EntraSecurityGroup' -Message 'Security group creation completed.' -Level Information
                $group
            }
        }
        catch {
            Write-EntraLog -Operation 'New-EntraSecurityGroup' -Message 'Security group creation failed. Review the terminating error.' -Level Warning
            throw
        }
    }
}
