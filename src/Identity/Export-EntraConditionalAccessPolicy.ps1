function Export-EntraConditionalAccessPolicy {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        try {
            if (Get-Command -Name Test-RequiredModule -ErrorAction SilentlyContinue) {
                $moduleCheck = Test-RequiredModule -Name Microsoft.Graph.Identity.SignIns -PassThruOnly
                if (-not $moduleCheck.IsAvailable) { throw 'Microsoft.Graph.Identity.SignIns is required for Export-EntraConditionalAccessPolicy.' }
            }

            $policies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop
            $exportObjects = foreach ($policy in $policies) {
                [pscustomobject]@{
                    Id          = $policy.Id
                    DisplayName = $policy.DisplayName
                    State       = $policy.State
                    CreatedDateTime = $policy.CreatedDateTime
                    ModifiedDateTime = $policy.ModifiedDateTime
                    Conditions  = $policy.Conditions
                    GrantControls = $policy.GrantControls
                    SessionControls = $policy.SessionControls
                }
            }

            if ($OutputPath) {
                $directory = Split-Path -Path $OutputPath -Parent
                if ($directory -and -not (Test-Path -Path $directory -PathType Container)) {
                    New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }
                $exportObjects | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding UTF8 -ErrorAction Stop
            }

            if ($PassThru.IsPresent -or -not $OutputPath) { $exportObjects }
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Conditional Access export failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }
            throw
        }
    }
}
