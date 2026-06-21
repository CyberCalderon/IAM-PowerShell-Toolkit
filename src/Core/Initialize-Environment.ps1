function Initialize-Environment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryRoot = $PWD,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationPath = (Join-Path -Path $PWD -ChildPath '.context\utilitybelt.config.psd1'),

        [Parameter()]
        [string[]]$RequiredModule,

        [Parameter()]
        [switch]$SkipModuleCheck,

        [Parameter()]
        [switch]$ImportRequiredModule
    )

    begin {
        $corePath = Join-Path -Path $RepositoryRoot -ChildPath 'src\Core'
        $environmentStarted = Get-Date
    }

    process {
        try {
            if (-not (Test-Path -Path $corePath -PathType Container)) {
                throw "Core path was not found: $corePath"
            }

            $coreScripts = @(
                'Initialize-Logger.ps1',
                'Test-RequiredModule.ps1',
                'Get-UtilityBeltConfiguration.ps1',
                'Protect-SecretValue.ps1'
            )

            foreach ($coreScript in $coreScripts) {
                $scriptPath = Join-Path -Path $corePath -ChildPath $coreScript

                if (Test-Path -Path $scriptPath -PathType Leaf) {
                    . $scriptPath
                }
            }

            $configuration = Get-UtilityBeltConfiguration -ConfigurationPath $ConfigurationPath -CreateDefault
            $minimumPowerShellVersion = [version]$configuration.PowerShell.MinimumVersion

            if ($PSVersionTable.PSVersion -lt $minimumPowerShellVersion) {
                throw "PowerShell $minimumPowerShellVersion or later is required. Current version is $($PSVersionTable.PSVersion)."
            }

            $logDirectory = Join-Path -Path $RepositoryRoot -ChildPath $configuration.Logging.LogDirectory

            if (-not (Test-Path -Path $logDirectory -PathType Container)) {
                New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }

            Initialize-Logger -LogLevel Information -LogMessage 'Utility Belt environment initialization started.' -LogDirectory $logDirectory -NoHostOutput | Out-Null

            $moduleResults = @()

            if (-not $SkipModuleCheck.IsPresent) {
                $moduleNames = if ($RequiredModule) {
                    $RequiredModule
                }
                else {
                    @($configuration.RequiredModules.Keys)
                }

                $moduleResults = Test-RequiredModule -Name $moduleNames -MinimumVersion $configuration.RequiredModules -ImportModule:$ImportRequiredModule.IsPresent -PassThruOnly

                foreach ($moduleResult in $moduleResults) {
                    $logLevel = if ($moduleResult.IsAvailable -and $moduleResult.MeetsVersion) { 'Information' } else { 'Warning' }
                    Initialize-Logger -LogLevel $logLevel -LogMessage "Environment module check: $($moduleResult.Name) - $($moduleResult.Status)." -LogDirectory $logDirectory -NoHostOutput | Out-Null
                }
            }

            $elapsed = New-TimeSpan -Start $environmentStarted -End (Get-Date)
            Initialize-Logger -LogLevel Information -LogMessage "Utility Belt environment initialization completed in $($elapsed.TotalMilliseconds) ms." -LogDirectory $logDirectory -NoHostOutput | Out-Null

            [pscustomobject]@{
                RepositoryRoot    = $RepositoryRoot
                CorePath          = $corePath
                ConfigurationPath = $configuration.ConfigurationPath
                LogDirectory      = $logDirectory
                PowerShellVersion = [string]$PSVersionTable.PSVersion
                ModuleResults     = $moduleResults
                InitializedAt     = Get-Date
            }
        }
        catch {
            if (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue) {
                Initialize-Logger -LogLevel Error -LogMessage "Environment initialization failed. $($_.Exception.Message)" -NoHostOutput | Out-Null
            }

            throw
        }
        finally {
            $environmentStarted = $null
        }
    }
}
