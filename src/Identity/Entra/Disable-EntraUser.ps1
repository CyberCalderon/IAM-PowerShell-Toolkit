#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function Disable-EntraUser {
    <#
    .SYNOPSIS
    Disables sign-in for a cloud-only Member user.
    .DESCRIPTION
    Requires User.EnableDisableAccount.All and User.Read.All application
    permissions. This changes accountEnabled; it does not revoke existing tokens
    or sessions. Synced users and guests are excluded from this lab workflow.
    .PARAMETER TenantId
    Expected lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER UserId
    User object GUID discovered in the personal lab tenant.
    .EXAMPLE
    $labUser = Get-EntraUser -Filter "displayName eq 'Contoso Lab Alex'"
    Disable-EntraUser -UserId $labUser.Id -WhatIf
    .EXAMPLE
    Disable-EntraUser -UserId $labUser.Id -Confirm
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string]$TenantId = $env:ENTRA_TENANT_ID,
        [Parameter(Mandatory)][ValidateScript({ $_ -ne [guid]::Empty })][guid]$UserId
    )

    try {
        Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Users'
        $null = Assert-EntraCloudUser -UserId $UserId
        if ($PSCmdlet.ShouldProcess($UserId.ToString(), 'Disable Entra lab user sign-in')) {
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Disabling lab user sign-in.'
            Update-MgUser -UserId $UserId.ToString() -BodyParameter @{ accountEnabled = $false } -Confirm:$false -ErrorAction Stop
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Lab user sign-in disabled.'
        }
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'User disable failed. Review the terminating error in your private session.'
        throw
    }
}
