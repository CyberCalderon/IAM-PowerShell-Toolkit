#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function Get-EntraUser {
    <#
    .SYNOPSIS
    Gets an Entra user by object ID or lists users with optional filtering.
    .DESCRIPTION
    Requires User.Read.All application permission. Lists all pages by default;
    -Top limits the result. Uses an existing validated lab Graph connection.
    .PARAMETER TenantId
    Expected personal lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER UserId
    Immutable user object GUID. Obtain it from a lab discovery query.
    .PARAMETER Filter
    Microsoft Graph OData filter. Advanced queries use eventual consistency.
    .PARAMETER Top
    Maximum number of users to return; omit to retrieve all pages.
    .EXAMPLE
    Get-EntraUser -Filter "startsWith(displayName,'Contoso Lab')" -Top 10
    .EXAMPLE
    Get-EntraUser -UserId $labUser.Id -InformationAction Continue
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [string]$TenantId = $env:ENTRA_TENANT_ID,
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateScript({ $_ -ne [guid]::Empty })][guid]$UserId,
        [Parameter(ParameterSetName = 'List')][ValidateNotNullOrEmpty()][string]$Filter,
        [Parameter(ParameterSetName = 'List')][ValidateRange(1, 999)][int]$Top
    )

    try {
        Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Users'
        $parameters = @{
            Property = @('id', 'displayName', 'userPrincipalName', 'accountEnabled', 'userType', 'onPremisesSyncEnabled')
            ErrorAction = 'Stop'
        }
        if ($PSCmdlet.ParameterSetName -eq 'ById') { $parameters.UserId = $UserId.ToString() }
        else {
            if ($PSBoundParameters.ContainsKey('Top')) { $parameters.Top = $Top }
            else { $parameters.All = $true }
            if ($Filter) {
                $parameters.Filter = $Filter
                $parameters.ConsistencyLevel = 'eventual'
                $parameters.CountVariable = 'entraUserCount'
            }
        }
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Reading users.'
        Get-MgUser @parameters
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'User query completed.'
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'User query failed. Review the terminating error in your private session.'
        throw
    }
}
