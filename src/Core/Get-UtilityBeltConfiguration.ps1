function Get-UtilityBeltConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath = (Join-Path -Path $PWD -ChildPath '.context\utilitybelt.config.psd1'),

        [Parameter()]
        [switch]$CreateDefault
    )

    begin {
        $defaultConfiguration = @{
            ProjectName = 'PowerShell AI Utility Belt'
            PowerShell = @{
                MinimumVersion = '7.0'
            }
            Logging = @{
                LogDirectory     = 'logs'
                LogFileName      = 'utility-belt.log'
                MaxLogFileSizeMB = 10
            }
            RequiredModules = @{
                Pester            = '5.0.0'
                'Microsoft.Graph' = '2.0.0'
                ActiveDirectory   = $null
            }
            Identity = @{
                GraphScopes = @(
                    'User.Read.All',
                    'Group.Read.All',
                    'Application.Read.All',
                    'Policy.Read.All'
                )
            }
        }
    }

    process {
        try {
            if ((Test-Path -Path $ConfigurationPath -PathType Leaf)) {
                $configuration = Import-PowerShellDataFile -Path $ConfigurationPath -ErrorAction Stop
            }
            else {
                $configuration = $defaultConfiguration

                if ($CreateDefault.IsPresent) {
                    $configurationDirectory = Split-Path -Path $ConfigurationPath -Parent

                    if (-not (Test-Path -Path $configurationDirectory -PathType Container)) {
                        New-Item -Path $configurationDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    }

                    $configurationContent = @"
@{
    ProjectName = 'PowerShell AI Utility Belt'
    PowerShell = @{
        MinimumVersion = '7.0'
    }
    Logging = @{
        LogDirectory     = 'logs'
        LogFileName      = 'utility-belt.log'
        MaxLogFileSizeMB = 10
    }
    RequiredModules = @{
        Pester            = '5.0.0'
        'Microsoft.Graph' = '2.0.0'
        ActiveDirectory   = `$null
    }
    Identity = @{
        GraphScopes = @(
            'User.Read.All',
            'Group.Read.All',
            'Application.Read.All',
            'Policy.Read.All'
        )
    }
}
"@

                    Set-Content -Path $ConfigurationPath -Value $configurationContent -Encoding UTF8 -ErrorAction Stop
                }
            }

            [pscustomobject]@{
                ConfigurationPath = $ConfigurationPath
                ProjectName       = $configuration.ProjectName
                PowerShell        = $configuration.PowerShell
                Logging           = $configuration.Logging
                RequiredModules   = $configuration.RequiredModules
                Identity          = $configuration.Identity
            }
        }
        catch {
            $message = "Unable to load Utility Belt configuration from '$ConfigurationPath'. $($_.Exception.Message)"

            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage $message -NoHostOutput | Out-Null
            }

            throw $message
        }
    }
}
