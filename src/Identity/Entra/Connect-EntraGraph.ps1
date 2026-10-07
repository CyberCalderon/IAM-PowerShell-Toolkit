#requires -Version 7.2
. (Join-Path $PSScriptRoot 'Private/Entra.Common.ps1')

function Connect-EntraGraph {
    <#
    .SYNOPSIS
    Connects to Microsoft Graph with an app registration and certificate.
    .DESCRIPTION
    Uses certificate-based application authentication in the Global cloud with a
    process-scoped context. Tenant/client IDs and the thumbprint can be supplied
    through ENTRA_TENANT_ID, ENTRA_CLIENT_ID and ENTRA_CERTIFICATE_THUMBPRINT.
    Supply an X509Certificate2 with a private key for cross-platform use. No
    permissions are requested at login: application permissions need admin consent.
    .PARAMETER TenantId
    Personal lab tenant GUID; defaults to ENTRA_TENANT_ID.
    .PARAMETER ClientId
    Lab app registration client GUID; defaults to ENTRA_CLIENT_ID.
    .PARAMETER CertificateThumbprint
    Exact thumbprint in the selected Windows certificate store.
    .PARAMETER CertificateStore
    Windows certificate store location; defaults to CurrentUser. The certificate
    is resolved from its My store and validated before authentication.
    .PARAMETER Certificate
    An unexpired X509Certificate2 with an accessible private key.
    .EXAMPLE
    . ./src/Identity/Entra/Connect-EntraGraph.ps1
    Connect-EntraGraph -InformationAction Continue
    Uses locally configured environment values for the fake Contoso lab.
    .EXAMPLE
    Connect-EntraGraph -TenantId $labTenantId -ClientId $labClientId -Certificate $labCertificate
    Uses a certificate object obtained privately outside the repository.
    .OUTPUTS
    Microsoft.Graph.PowerShell.Authentication.Models.GraphContext
    #>
    [CmdletBinding(DefaultParameterSetName = 'Thumbprint')]
    param(
        [string]$TenantId = $env:ENTRA_TENANT_ID,
        [string]$ClientId = $env:ENTRA_CLIENT_ID,
        [Parameter(ParameterSetName = 'Thumbprint')]
        [string]$CertificateThumbprint = $env:ENTRA_CERTIFICATE_THUMBPRINT,
        [Parameter(ParameterSetName = 'Thumbprint')]
        [ValidateSet('CurrentUser', 'LocalMachine')][string]$CertificateStore = 'CurrentUser',
        [Parameter(Mandatory, ParameterSetName = 'Certificate')]
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    try {
        $tenant = [guid]::Empty
        $client = [guid]::Empty
        if (-not [guid]::TryParse($TenantId, [ref]$tenant) -or $tenant -eq [guid]::Empty) {
            throw 'Provide a nonempty tenant GUID through -TenantId or ENTRA_TENANT_ID.'
        }
        if (-not [guid]::TryParse($ClientId, [ref]$client) -or $client -eq [guid]::Empty) {
            throw 'Provide a nonempty client GUID through -ClientId or ENTRA_CLIENT_ID.'
        }
        $parameters = @{
            TenantId = $tenant.ToString()
            ClientId = $client.ToString()
            ContextScope = 'Process'
            Environment = 'Global'
            NoWelcome = $true
            ErrorAction = 'Stop'
        }
        if ($PSCmdlet.ParameterSetName -eq 'Certificate') {
            $selectedCertificate = $Certificate
        }
        else {
            if ([string]::IsNullOrWhiteSpace($CertificateThumbprint) -or $CertificateThumbprint -notmatch '\A[0-9a-fA-F]{40}\z') {
                throw 'Provide a valid certificate thumbprint through -CertificateThumbprint or ENTRA_CERTIFICATE_THUMBPRINT.'
            }
            $selectedCertificate = Get-Item -LiteralPath "Cert:\$CertificateStore\My\$CertificateThumbprint" -ErrorAction Stop
            if ($selectedCertificate.Thumbprint -ne $CertificateThumbprint) {
                throw 'The certificate store did not return the exact requested certificate.'
            }
        }
        if (-not $selectedCertificate.HasPrivateKey -or $selectedCertificate.NotBefore.ToUniversalTime() -gt [datetime]::UtcNow -or
            $selectedCertificate.NotAfter.ToUniversalTime() -le [datetime]::UtcNow) {
            throw 'The certificate must be currently valid and have an accessible private key.'
        }
        $parameters.Certificate = $selectedCertificate
        Import-EntraGraphModule -Name 'Microsoft.Graph.Authentication'
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Opening the certificate-authenticated lab connection.'
        Connect-MgGraph @parameters | Out-Null
        Assert-EntraGraphSession -TenantId $tenant.ToString() -RequiredModule 'Microsoft.Graph.Authentication'
        $context = Get-MgContext -ErrorAction Stop
        if ($context.ClientId -ne $client.ToString()) { throw 'The active Graph connection does not match the requested application.' }
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Message 'Connection established and validated.'
        return $context
    }
    catch {
        Write-EntraLog -Operation $MyInvocation.MyCommand.Name -Level Warning -Message 'Connection failed. Review the terminating error in your private session.'
        throw
    }
}
