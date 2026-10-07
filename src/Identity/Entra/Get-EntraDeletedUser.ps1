#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function Get-EntraDeletedUser {
    <#
    .SYNOPSIS
    Lists soft-deleted Entra users or gets one by object ID.
    .DESCRIPTION
    Requires User.Read.All application permission. Uses the typed user endpoint
    rather than returning arbitrary deleted directory objects. All pages are
    retrieved unless -Top is supplied. Recovery is normally possible for 30 days.
    .PARAMETER TenantId
    Expected lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER UserId
    Immutable object GUID of a deleted lab user.
    .PARAMETER Filter
    Supported Microsoft Graph OData filter for deleted users. Filtered queries
    request eventual consistency and a count to support advanced user queries.
    .PARAMETER Top
    Maximum users to retrieve; omit to retrieve all pages.
    .EXAMPLE
    Get-EntraDeletedUser -Filter "startsWith(displayName,'Contoso Lab')"
    .EXAMPLE
    Get-EntraDeletedUser -UserId $labUser.Id
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
        Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Identity.DirectoryManagement'
        $parameters = @{
            Property = @('id', 'displayName', 'userPrincipalName', 'deletedDateTime', 'userType', 'onPremisesSyncEnabled')
            ErrorAction = 'Stop'
        }
        if ($PSCmdlet.ParameterSetName -eq 'ById') { $parameters.DirectoryObjectId = $UserId.ToString() }
        else {
            if ($PSBoundParameters.ContainsKey('Top')) { $parameters.Top = $Top }
            else { $parameters.All = $true }
            if ($Filter) {
                $parameters.Filter = $Filter
                $parameters.Headers = @{ ConsistencyLevel = 'eventual' }
                $parameters.CountVariable = 'entraDeletedUserCount'
            }
        }
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Reading soft-deleted users.'
        Get-MgDirectoryDeletedItemAsUser @parameters
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Deleted user query completed.'
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'Deleted user query failed. Review the terminating error in your private session.'
        throw
    }
}
