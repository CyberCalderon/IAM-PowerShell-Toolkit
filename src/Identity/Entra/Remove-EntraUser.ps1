#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function Remove-EntraUser {
    <#
    .SYNOPSIS
    Soft-deletes a cloud-only Member user in the personal lab.
    .DESCRIPTION
    Requires User.DeleteRestore.All application permission plus User.Read.All
    for the preflight. Calls Remove-MgUser only; never permanently purges deleted items.
    Synced users and guests are excluded. Confirmation is requested by default.
    .PARAMETER TenantId
    Expected lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER UserId
    Immutable lab user object GUID obtained from Get-EntraUser.
    .EXAMPLE
    $labUser = Get-EntraUser -Filter "displayName eq 'Contoso Lab Alex'"
    Remove-EntraUser -UserId $labUser.Id -WhatIf
    .EXAMPLE
    Remove-EntraUser -UserId $labUser.Id -Confirm
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string]$TenantId = $env:ENTRA_TENANT_ID,
        [Parameter(Mandatory)][ValidateScript({ $_ -ne [guid]::Empty })][guid]$UserId
    )

    try {
        Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Users'
        $null = Assert-EntraCloudUser -UserId $UserId
        if ($PSCmdlet.ShouldProcess($UserId.ToString(), 'Soft-delete Entra lab user')) {
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Soft-deleting a lab user.'
            Remove-MgUser -UserId $UserId.ToString() -Confirm:$false -ErrorAction Stop
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Lab user soft-deleted.'
        }
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'User deletion failed. Review the terminating error in your private session.'
        throw
    }
}
