#requires -Version 7.2
. (Join-Path -Path $PSScriptRoot -ChildPath 'Private/Entra.Common.ps1')

function Get-EntraGroupMember {
    <#
    .SYNOPSIS
    Gets the direct members of a static Entra security group.
    .DESCRIPTION
    Returns all direct directory object members by default, including non-user
    object types. Specify Top to request a bounded result instead. Nested group
    members are not expanded. The group must be cloud-only, static,
    non-mail-enabled, and non-role-assignable, and the connected tenant must
    match TenantId. Requires the GroupMember.Read.All application permission
    with administrator consent. Graph may return limited properties for member
    types that the application does not have permission to read.
    .PARAMETER GroupId
    The object ID of the existing lab security group.
    .PARAMETER Top
    Limits the result to between 1 and 999 direct members. Omit for all members.
    .PARAMETER TenantId
    The expected lab tenant ID. Defaults to ENTRA_TENANT_ID.
    .EXAMPLE
    $owner = Get-EntraUser -Filter "displayName eq 'Contoso Lab Owner'"
    $group = New-EntraSecurityGroup -DisplayName 'Contoso Lab Readers' -MailNickname 'contoso-lab-readers' -OwnerUserId $owner.Id
    Get-EntraGroupMember -GroupId $group.Id
    Gets all direct directory object members of the Contoso lab group.
    .EXAMPLE
    Get-EntraGroupMember -GroupId $group.Id -Top 25
    Gets at most 25 direct members of an existing lab group.
    .OUTPUTS
    Microsoft.Graph.PowerShell.Models.IMicrosoftGraphDirectoryObject
    .NOTES
    Requires PowerShell 7.2+, Microsoft.Graph.Authentication, and
    Microsoft.Graph.Groups. The Graph v1.0 group-members endpoint has a known
    limitation that may omit service principals from its results.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'All')]
        [Parameter(Mandatory, ParameterSetName = 'Top')]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$GroupId,

        [Parameter(Mandatory, ParameterSetName = 'Top')]
        [ValidateRange(1, 999)]
        [int]$Top,

        [Parameter()]
        [string]$TenantId = $env:ENTRA_TENANT_ID
    )

    process {
        try {
            Write-EntraLog -Operation 'Get-EntraGroupMember' -Message 'Starting direct group membership retrieval.' -Level Information
            Assert-EntraGraphSession -TenantId $TenantId -RequiredModule 'Microsoft.Graph.Groups'
            $null = Assert-EntraStaticSecurityGroup -GroupId $GroupId

            $parameters = @{
                GroupId     = $GroupId
                ErrorAction = 'Stop'
            }
            if ($PSCmdlet.ParameterSetName -eq 'Top') {
                $parameters['Top'] = $Top
            }
            else {
                $parameters['All'] = $true
            }

            Get-MgGroupMember @parameters
            Write-EntraLog -Operation 'Get-EntraGroupMember' -Message 'Direct group membership retrieval completed.' -Level Information
        }
        catch {
            Write-EntraLog -Operation 'Get-EntraGroupMember' -Message 'Direct group membership retrieval failed. Review the terminating error.' -Level Warning
            throw
        }
    }
}
