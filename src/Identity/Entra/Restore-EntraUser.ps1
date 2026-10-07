#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function Restore-EntraUser {
    <#
    .SYNOPSIS
    Restores a soft-deleted cloud-only Member user.
    .DESCRIPTION
    Requires User.DeleteRestore.All for restore and User.Read.All for the typed
    deleted-user preflight. Does not resolve name/proxy-address conflicts or
    change the restored account's enabled state. Review that state after restore.
    .PARAMETER TenantId
    Expected lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER UserId
    Deleted user object GUID obtained from Get-EntraDeletedUser.
    .EXAMPLE
    $deleted = Get-EntraDeletedUser -Filter "displayName eq 'Contoso Lab Alex'"
    Restore-EntraUser -UserId $deleted.Id -WhatIf
    .EXAMPLE
    Restore-EntraUser -UserId $deleted.Id -Confirm
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$TenantId = $env:ENTRA_TENANT_ID,
        [Parameter(Mandatory)][ValidateScript({ $_ -ne [guid]::Empty })][guid]$UserId
    )

    try {
        Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Identity.DirectoryManagement'
        $user = Get-MgDirectoryDeletedItemAsUser -DirectoryObjectId $UserId.ToString() -Property @('id', 'userType', 'onPremisesSyncEnabled') -ErrorAction Stop
        if (-not $user -or $user.Id -ne $UserId.ToString() -or $user.UserType -ne 'Member' -or $user.OnPremisesSyncEnabled -eq $true) {
            throw 'Restore requires a soft-deleted cloud-only Member user. Synced users and guests are excluded.'
        }
        if ($PSCmdlet.ShouldProcess($UserId.ToString(), 'Restore soft-deleted Entra lab user')) {
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Restoring a soft-deleted lab user.'
            Restore-MgDirectoryDeletedItem -DirectoryObjectId $UserId.ToString() -Confirm:$false -ErrorAction Stop
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Lab user restored; review account state and memberships.'
        }
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'User restore failed. Review the terminating error in your private session.'
        throw
    }
}
