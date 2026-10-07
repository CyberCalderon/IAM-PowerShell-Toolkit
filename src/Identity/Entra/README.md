
# Microsoft Entra ID lab lifecycle automation

These PowerShell functions demonstrate Microsoft Graph certificate authentication, user lifecycle management, and direct security group membership management for a personal IAM portfolio. Use a dedicated Entra lab tenant containing only synthetic accounts. The lifecycle functions are separate from the existing inventory, application audit, and Conditional Access export scripts in this directory.

All configuration comes from parameters or local environment variables. No function embeds a tenant ID, application ID, certificate thumbprint, domain, username, or directory object ID. The Contoso examples below are fictional; supply your own lab values locally without adding them to source control.

## Prerequisites

- PowerShell 7.2 or later.
- Microsoft Graph PowerShell SDK 2.x. Install the modules below for these lifecycle functions.
- A personal Entra lab tenant, an app registration in that tenant, and a certificate whose private key is available only to the account running PowerShell.
- An administrator authorized to grant the necessary Microsoft Graph **application** permissions and tenant-wide admin consent. Authentication here is app-only; delegated scopes do not configure these permissions.
- Pester 5.x for the offline test suite.

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users,
    Microsoft.Graph.Groups,
    Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser

Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
```

Review package sources and versions before installation. The functions load the modules they need and return a terminating error when a prerequisite or operation fails.

## Functions and permissions

Application permissions apply across the tenant. Grant only the permissions needed for a chosen workflow; separate a read-only app registration from an app allowed to mutate users or memberships. Permissions in this table include the reads used by the wrappers to validate the target before a change. Admin consent is required.

| Function | Behavior | Microsoft Graph application permissions |
| --- | --- | --- |
| `Connect-EntraGraph` | Connect with a certificate; use a process-scoped app-only context | No additional permission for connection itself; grant permissions for subsequent operations |
| `Get-EntraUser` | Get a user, filter users, or enumerate all active users | `User.Read.All` ([list users](https://learn.microsoft.com/graph/api/user-list?view=graph-rest-1.0)) |
| `New-EntraUser` | Create a cloud-only user, disabled by default | `User.Create` ([create user](https://learn.microsoft.com/graph/api/user-post-users?view=graph-rest-1.0)) |
| `Disable-EntraUser` | Set `accountEnabled` to false after validating the user | `User.EnableDisableAccount.All` **and** `User.Read.All` ([update user](https://learn.microsoft.com/graph/api/user-update?view=graph-rest-1.0)) |
| `Get-EntraDeletedUser` | Get or list soft-deleted users | `User.Read.All` ([list deleted items](https://learn.microsoft.com/graph/api/directory-deleteditems-list?view=graph-rest-1.0)) |
| `Restore-EntraUser` | Restore a soft-deleted cloud-only user after validation | `User.DeleteRestore.All` and `User.Read.All` ([restore deleted item](https://learn.microsoft.com/graph/api/directory-deleteditems-restore?view=graph-rest-1.0)) |
| `Remove-EntraUser` | Soft-delete a cloud-only user after validation | `User.DeleteRestore.All` and `User.Read.All` ([SDK delete permissions](https://learn.microsoft.com/powershell/module/microsoft.graph.users/remove-mguser?view=graph-powershell-1.0), [permission definition](https://learn.microsoft.com/graph/permissions-reference#userdeleterestoreall)) |
| `New-EntraSecurityGroup` | Create a static security group with a specified lab user owner | `Group.Create` and `User.Read.All` for the owner preflight ([create group](https://learn.microsoft.com/graph/api/group-post-groups?view=graph-rest-1.0)) |
| `Add-EntraGroupMember` | Add a user to a static security group | `GroupMember.ReadWrite.All` and `User.Read.All` for the user preflight ([add member](https://learn.microsoft.com/graph/api/group-post-members?view=graph-rest-1.0)) |
| `Remove-EntraGroupMember` | Remove only the membership reference | `GroupMember.ReadWrite.All` and `User.Read.All` for the user preflight ([remove member](https://learn.microsoft.com/graph/api/group-delete-members?view=graph-rest-1.0)) |
| `Get-EntraGroupMember` | Enumerate direct members of a static security group | `GroupMember.Read.All` ([list members](https://learn.microsoft.com/graph/api/group-list-members?view=graph-rest-1.0)) |

Microsoft Graph permissions evolve. The linked API and SDK references describe current endpoint permissions; older SDKs, unconsented permissions, or unavailable permissions in a tenant can cause failures. For user deletion, the SDK and permission reference document the narrower `User.DeleteRestore.All`, while the REST delete-user page still lists `User.ReadWrite.All`; this workflow uses the narrower documented permission. These functions target the global Microsoft Graph cloud. Do not add broad `Directory.ReadWrite.All` permissions to bypass an authorization failure.

The group wrappers validate the group before operating. They accept cloud-only, static, security-enabled groups and reject mail-enabled, dynamic, synchronized, and role-assignable groups. User mutation and membership wrappers require cloud-only Member users and reject Guest or synchronized identities. This is a deliberately narrow lab workflow; privileged identity and role-assignable group administration require separate controls and permissions.

Group enumeration returns direct directory objects, not transitive membership. Graph can return only an object's ID and type when the app lacks permission to read that object's properties. `GroupMember.Read.All` is sufficient to enumerate ordinary memberships; grant an additional read permission only when the required object details justify it. Hidden membership needs `Member.Read.Hidden` and is outside these examples. The Graph v1.0 list-members API has a documented limitation involving service principal members; review the linked API reference before using its output as a complete mixed-object audit.

## Certificate authentication setup

1. Register a single-tenant application in your personal lab tenant. Record its application/client ID and the lab tenant ID in a local configuration mechanism, outside this repository.
2. Grant only the selected **application** permissions from the table, then grant admin consent.
3. Create or obtain a certificate and retain its private key in an appropriately protected certificate store, secret store, or signing service. Upload only the public certificate to **App registrations → Certificates & secrets → Certificates**.
4. Set local configuration and connect using either the certificate object or its Windows certificate-store thumbprint. Thumbprint lookup defaults to `Cert:\CurrentUser\My`; use `-CertificateStore LocalMachine` to select `Cert:\LocalMachine\My` when its private key access is configured for the caller.

For a Windows-only personal lab, this example creates a short-lived, non-exportable self-signed private key in the current user's certificate store. A production deployment should follow its certificate issuance, storage, monitoring, and rotation policy.

```powershell
$labCertificate = New-SelfSignedCertificate `
    -Subject 'CN=EntraPortfolioLab' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
    -KeySpec Signature -KeyExportPolicy NonExportable `
    -NotAfter (Get-Date).AddMonths(6)

# This folder is outside the repository. Only the public certificate is exported.
$certificateFolder = Join-Path $env:LOCALAPPDATA 'EntraPortfolioLab'
New-Item -ItemType Directory -Path $certificateFolder -Force | Out-Null
Export-Certificate -Cert $labCertificate `
    -FilePath (Join-Path $certificateFolder 'EntraPortfolioLab.cer') | Out-Null

# Enter values locally; never replace these prompts with committed identifiers.
$env:ENTRA_TENANT_ID = Read-Host 'Personal lab tenant ID'
$env:ENTRA_CLIENT_ID = Read-Host 'Personal lab application/client ID'
$env:ENTRA_CERTIFICATE_THUMBPRINT = $labCertificate.Thumbprint
```

Upload the exported `.cer` to the app registration before connecting. Do not export or upload the private key. Grant the automation identity access to its private key only, and remove certificates and app permissions that are no longer needed.

Load the lifecycle functions from the repository root:

```powershell
$entraPath = Join-Path $PWD 'src/Identity/Entra'
$functionNames = @(
    'Connect-EntraGraph', 'Get-EntraUser', 'New-EntraUser',
    'Disable-EntraUser', 'Get-EntraDeletedUser', 'Restore-EntraUser',
    'Remove-EntraUser', 'New-EntraSecurityGroup', 'Add-EntraGroupMember',
    'Remove-EntraGroupMember', 'Get-EntraGroupMember'
)
foreach ($functionName in $functionNames) {
    . (Join-Path $entraPath "$functionName.ps1")
}

# Windows certificate store: local environment variables supply all three values.
Connect-EntraGraph -Verbose

# Alternatively, supply explicit IDs and an X509Certificate2 with a private key.
# This route can also be used on non-Windows systems with a securely loaded object.
Connect-EntraGraph -TenantId $env:ENTRA_TENANT_ID `
    -ClientId $env:ENTRA_CLIENT_ID -Certificate $labCertificate -Verbose
```

The connection validates the selected certificate's current validity period and private key presence before authentication, then uses Microsoft Graph's `Global` environment and `Process` context scope. Thumbprint lookup is Windows-only; use `-Certificate` with a securely loaded `X509Certificate2` on other platforms. Each lifecycle function verifies that the current context is app-only and matches its expected `TenantId`, which defaults to `ENTRA_TENANT_ID`; pass `-TenantId` explicitly when not using that variable. The check helps prevent a command from acting through an unrelated connection in the current shell. Certificate possession authenticates the application; assigned Graph application permissions determine what it can do.

Use `Disconnect-MgGraph` when finished. Environment variables are local runtime configuration, not a secret vault; never print, export, or commit them.

## Lab examples

Every mutation supports `-WhatIf` and `-Confirm`. `Disable-EntraUser`, `Remove-EntraUser`, and `Remove-EntraGroupMember` have high confirmation impact and prompt under normal PowerShell settings. Create, restore, and add operations have medium impact; use `-Confirm` when you want an explicit prompt. `-WhatIf` still validates the connection and performs read-only preflight checks, so it requires an authenticated app with the relevant read permissions.

The following example addresses are fake Contoso data. A real execution needs a verified domain in your personal lab tenant. Leave `-Enabled` unset to create a disabled user, and enter the initial password through a secure prompt. The user must change the password at the next sign-in.

```powershell
Get-EntraUser -Top 10
Get-EntraUser -Filter "startsWith(displayName,'Contoso Lab')"

$initialPassword = Read-Host 'Initial password for the synthetic lab account' -AsSecureString
$newUserParameters = @{
    DisplayName       = 'Contoso Lab User'
    UserPrincipalName = 'lab.user@contoso.example'
    MailNickname      = 'lab.user'
    Password          = $initialPassword
}
New-EntraUser @newUserParameters -WhatIf
$labUser = New-EntraUser @newUserParameters -Confirm
```

Select a cloud-only Member lab user as the group's explicit owner. Its object ID is entered locally; the function checks that it meets the same cloud-only user restrictions before creation.

```powershell
$ownerUserId = Read-Host 'Cloud-only Member lab owner object ID'
$newGroupParameters = @{
    DisplayName = 'Contoso Lab Security Group'
    MailNickname = 'contoso-lab-security'
    Description = 'Synthetic IAM portfolio lab membership'
    OwnerUserId = $ownerUserId
}
New-EntraSecurityGroup @newGroupParameters -WhatIf
$labGroup = New-EntraSecurityGroup @newGroupParameters -Confirm

Add-EntraGroupMember -GroupId $labGroup.Id -UserId $labUser.Id -WhatIf
Add-EntraGroupMember -GroupId $labGroup.Id -UserId $labUser.Id -Confirm
Get-EntraGroupMember -GroupId $labGroup.Id

Remove-EntraGroupMember -GroupId $labGroup.Id -UserId $labUser.Id -WhatIf
Remove-EntraGroupMember -GroupId $labGroup.Id -UserId $labUser.Id -Confirm
```

When testing existing lab users, enter their object IDs locally and inspect the selected object before running a change. User mutations accept object IDs, avoiding ambiguity from renamed usernames.

```powershell
$labUserId = Read-Host 'Synthetic lab user object ID'
Get-EntraUser -UserId $labUserId

Disable-EntraUser -UserId $labUserId -WhatIf
Disable-EntraUser -UserId $labUserId -Confirm

Remove-EntraUser -UserId $labUserId -WhatIf
Remove-EntraUser -UserId $labUserId -Confirm
Get-EntraDeletedUser

Restore-EntraUser -UserId $labUserId -WhatIf
Restore-EntraUser -UserId $labUserId -Confirm
```

Inspect the restored user and its access before using it. Deleted users are normally retained for approximately 30 days; expired retention or an already permanently deleted account prevents restoration. Username, proxy address, or other directory conflicts can also prevent restoration. The wrapper surfaces those errors and does not resolve conflicts automatically or permanently delete directory objects.

For help on a specific function, including parameters and fictional examples:

```powershell
Get-Help New-EntraUser -Full
Get-Help Remove-EntraGroupMember -Examples
```

## Errors, logging, and verification

Validation and Graph failures are terminating errors so callers can use `try`/`catch`. `-Verbose` reports session validation, and `-InformationAction Continue` displays operation progress messages. Logging avoids passwords, access tokens, private keys, and certificate thumbprints. Confirmation output and raw Graph errors can still contain identifying information; keep lab logs outside the public repository and review them before sharing.

Microsoft Graph SDK handles its supported transport retries and throttling behavior. These wrappers do not add mutation retry loops. After a timeout or uncertain response, read the directory state before rerunning a create, delete, restore, or membership change. Graph propagation can be delayed, and preflight validation cannot eliminate a race with another writer.

Run the dedicated lifecycle tests from the repository root:

```powershell
Invoke-Pester -Path ./tests/Entra.Lifecycle.Tests.ps1 -Output Detailed
```

The lifecycle suite mocks Graph calls and performs no authentication or live tenant changes. It exercises parameter validation, context checks, request construction, target restrictions, error handling, and `-WhatIf` behavior. It does not prove tenant permissions, certificate access, consent, or actual service behavior; validate those deliberately in the personal lab. Existing repository inventory and integration tests are separate from this suite.

## Security considerations

- Keep all real identifiers, tenant exports, logs, certificate files, and credentials outside this public repository. Do not use employer code or data. The scripts require no client secret and never commit authentication material.
- Give app registrations only the permissions needed for the current workflow. App-only permissions are tenant-wide; a target safety check is not an authorization boundary. Limit who can use the certificate and review sign-in/audit activity.
- A Member user can still hold administrator roles. Use synthetic lab identities with no administrative privileges; Graph may require additional directory role authorization for protected users. These functions neither assign that authorization nor bypass it.
- Inspect `-WhatIf` output and selected lab objects before changes. Confirmation does not make an unintended tenant or target safe. Avoid globally suppressing confirmation prompts.
- `Remove-EntraGroupMember` uses the Graph membership-reference deletion operation (`/$ref`), which removes membership without deleting the user. Omitting that suffix in a raw Graph request can delete a directory object when the application also holds the necessary delete permissions.
- Disabling an account does not guarantee immediate revocation of already-issued tokens or active sessions. These functions do not revoke sessions, remove licenses, manage authentication methods, alter role assignments, or implement a complete production offboarding procedure.
- Restoring a user can restore access relationships. Review memberships and assignments after recovery. Group creation supplies an explicit owner; these scripts do not delete groups or silently clean up created objects.
- Treat `SecureString` as protection for local password handling, not end-to-end encryption. The Graph request requires the initial password as plaintext transiently in memory; it is transmitted through the SDK over HTTPS and never written to logs or source files.
