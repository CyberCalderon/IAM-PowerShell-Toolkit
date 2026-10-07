#requires -Version 7.2
. (Join-Path -Path $PSScriptRoot -ChildPath 'Private/Entra.Common.ps1')

function Add-EntraGroupMember {
    <#
    .SYNOPSIS
    Adds a cloud-only member user to a static Entra security group.
    .DESCRIPTION
    Creates a Microsoft Graph membership reference. The group must be a
    cloud-only, static, non-mail-enabled, non-role-assignable security group;
    the user must be a cloud-only Member. The connected tenant must match
    TenantId. Requires GroupMember.ReadWrite.All and User.Read.All application
    permissions with administrator consent. User.Read.All supports the
    lab-safety user preflight check.
    .PARAMETER GroupId
    The object ID of the existing lab security group.
    .PARAMETER UserId
    The object ID of the existing cloud-only lab member user.
    .PARAMETER TenantId
    The expected lab tenant ID. Defaults to ENTRA_TENANT_ID.
    .EXAMPLE
    $user = Get-EntraUser -Filter "displayName eq 'Contoso Lab Reader'"
    $owner = Get-EntraUser -Filter "displayName eq 'Contoso Lab Owner'"
    $group = New-EntraSecurityGroup -DisplayName 'Contoso Lab Readers' -MailNickname 'contoso-lab-readers' -OwnerUserId $owner.Id
    Add-EntraGroupMember -GroupId $group.Id -UserId $user.Id -WhatIf
    Previews adding the selected Contoso lab user to the lab group.
    .EXAMPLE
    Add-EntraGroupMember -GroupId $group.Id -UserId $user.Id -Confirm
    Adds an existing lab user to an existing lab group after confirmation.
    .OUTPUTS
    None.
    .NOTES
    Requires PowerShell 7.2+, Microsoft.Graph.Authentication,
    Microsoft.Graph.Groups, and Microsoft.Graph.Users. Existing membership
    is reported through Graph's terminating error; it is not silently ignored.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$GroupId,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$UserId,

        [Parameter()]
        [string]$TenantId = $env:ENTRA_TENANT_ID
    )

    process {
        try {
            Write-EntraLog -Operation 'Add-EntraGroupMember' -Message 'Starting group membership addition.' -Level Information
            Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Groups'
            Import-EntraGraphModule -Name 'Microsoft.Graph.Users'
            $null = Assert-EntraStaticSecurityGroup -GroupId $GroupId
            $null = Assert-EntraCloudUser -UserId $UserId

            $body = @{
                '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
            }
            if ($PSCmdlet.ShouldProcess("Group $GroupId / user $UserId", 'Add Entra user to security group')) {
                New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $body -Confirm:$false -ErrorAction Stop
                Write-EntraLog -Operation 'Add-EntraGroupMember' -Message 'Group membership addition completed.' -Level Information
            }
        }
        catch {
            Write-EntraLog -Operation 'Add-EntraGroupMember' -Message 'Group membership addition failed. Review the terminating error.' -Level Warning
            throw
        }
    }
}
