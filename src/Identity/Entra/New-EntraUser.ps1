#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function New-EntraUser {
    <#
    .SYNOPSIS
    Creates a cloud-only Member user, disabled by default.
    .DESCRIPTION
    Requires User.Create application permission. The initial password is provided
    as a SecureString and must be changed at first sign-in. Microsoft Graph needs
    plaintext in memory for the request; it is never written to a log or file.
    Use a verified domain belonging only to your personal lab tenant.
    .PARAMETER TenantId
    Expected lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER DisplayName
    Display name for the new lab user.
    .PARAMETER UserPrincipalName
    Sign-in name in a verified personal lab domain.
    .PARAMETER MailNickname
    Unique mail alias for the user.
    .PARAMETER Password
    Initial password obtained with Read-Host -AsSecureString or a secure vault.
    .PARAMETER Enabled
    Enables the account on creation. Omit to create a disabled account.
    .EXAMPLE
    $password = Read-Host 'Initial password for the fake Contoso lab user' -AsSecureString
    New-EntraUser -DisplayName 'Contoso Lab Alex' -UserPrincipalName 'alex@contoso.example' -MailNickname 'contoso-lab-alex' -Password $password -WhatIf
    contoso.example is fake: replace it with your personal lab's verified domain.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$TenantId = $env:ENTRA_TENANT_ID,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateLength(1, 256)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][string]$DisplayName,
        [Parameter(Mandatory)][ValidatePattern('\A[^\s@]+@[^\s@]+\.[^\s@]+\z')][string]$UserPrincipalName,
        [Parameter(Mandatory)][ValidatePattern('\A[a-zA-Z0-9._-]{1,64}\z')][string]$MailNickname,
        [Parameter(Mandatory)][ValidateNotNull()][securestring]$Password,
        [switch]$Enabled
    )

    $passwordPointer = [IntPtr]::Zero
    $body = $null
    try {
        Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Users'
        if ($Password.Length -eq 0) { throw 'The initial password cannot be empty.' }
        if ($PSCmdlet.ShouldProcess($UserPrincipalName, 'Create cloud-only Entra lab user')) {
            $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            $body = @{
                accountEnabled = $Enabled.IsPresent
                displayName = $DisplayName
                userPrincipalName = $UserPrincipalName
                mailNickname = $MailNickname
                userType = 'Member'
                passwordProfile = @{
                    password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
                    forceChangePasswordNextSignIn = $true
                }
            }
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Creating a cloud-only lab user.'
            New-MgUser -BodyParameter $body -Confirm:$false -ErrorAction Stop
            Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Lab user created.'
        }
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'User creation failed. Review the terminating error in your private session.'
        throw
    }
    finally {
        if ($body) { $body.passwordProfile.Clear(); $body.Clear() }
        if ($passwordPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    }
}
