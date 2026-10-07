#requires -Version 7.2
. (Join-Path -Path $PSScriptRoot -ChildPath 'Private/Entra.Common.ps1')

function Remove-EntraGroupMember {
    <#
    .SYNOPSIS
    Removes a user's membership reference from a static Entra security group.
    .DESCRIPTION
    Uses Remove-MgGroupMemberDirectoryObjectByRef to remove only the membership
    reference.
    The user object is never deleted. The group must be a cloud-only, static,
    non-mail-enabled, non-role-assignable security group; the user must be a
    cloud-only Member. The connected tenant must match TenantId.
    Requires GroupMember.ReadWrite.All and User.Read.All application permissions
    with administrator consent. User.Read.All supports the lab-safety user
    preflight check.
    .PARAMETER GroupId
    The object ID of the existing lab security group.
    .PARAMETER UserId
    The object ID of the existing cloud-only lab member user.
    .PARAMETER TenantId
    The expected lab tenant ID. Defaults to ENTRA_TENANT_ID.
    .EXAMPLE
    $user = Get-EntraUser -Filter "displayName eq 'Contoso Lab Reader'"
    Remove-EntraGroupMember -GroupId $group.Id -UserId $user.Id -WhatIf
    Previews removal of the Contoso lab user's membership without changing it.
    .EXAMPLE
    Remove-EntraGroupMember -GroupId $group.Id -UserId $user.Id
    Prompts before removing the membership. The user remains in Entra.
    .OUTPUTS
    None.
    .NOTES
    Requires PowerShell 7.2+, Microsoft.Graph.Authentication,
    Microsoft.Graph.Groups, and Microsoft.Graph.Users. A missing membership
    is reported through Graph's terminating error; it is not silently ignored.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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
            Write-EntraLog -Operation 'Remove-EntraGroupMember' -Message 'Starting group membership removal.' -Level Information
            Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Groups'
            Import-EntraGraphModule -Name 'Microsoft.Graph.Users'
            $null = Assert-EntraStaticSecurityGroup -GroupId $GroupId
            $null = Assert-EntraCloudUser -UserId $UserId

            if ($PSCmdlet.ShouldProcess("Group $GroupId / user $UserId", 'Remove Entra user membership reference')) {
                Remove-MgGroupMemberDirectoryObjectByRef -GroupId $GroupId -DirectoryObjectId $UserId -Confirm:$false -ErrorAction Stop
                Write-EntraLog -Operation 'Remove-EntraGroupMember' -Message 'Group membership removal completed.' -Level Information
            }
        }
        catch {
            Write-EntraLog -Operation 'Remove-EntraGroupMember' -Message 'Group membership removal failed. Review the terminating error.' -Level Warning
            throw
        }
    }
}
