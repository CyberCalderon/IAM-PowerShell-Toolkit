function Test-RequiredModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter()]
        [hashtable]$MinimumVersion = @{},

        [Parameter()]
        [switch]$ImportModule,

        [Parameter()]
        [switch]$PassThruOnly
    )

    begin {
        $results = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($moduleName in $Name) {
            try {
                $availableModules = Get-Module -Name $moduleName -ListAvailable -ErrorAction Stop |
                    Sort-Object -Property Version -Descending

                $latestModule = $availableModules | Select-Object -First 1
                $requiredVersion = $MinimumVersion[$moduleName]
                $isAvailable = $null -ne $latestModule
                $meetsVersion = $true
                $imported = $false
                $status = 'Available'
                $message = 'Module is available.'

                if (-not $isAvailable) {
                    $meetsVersion = $false
                    $status = 'Missing'
                    $message = 'Module was not found in the current module paths.'
                }
                elseif ($requiredVersion -and ([version]$latestModule.Version -lt [version]$requiredVersion)) {
                    $meetsVersion = $false
                    $status = 'VersionMismatch'
                    $message = "Module version $($latestModule.Version) is lower than required version $requiredVersion."
                }

                if ($isAvailable -and $meetsVersion -and $ImportModule.IsPresent) {
                    Import-Module -Name $moduleName -ErrorAction Stop
                    $imported = $true
                    $message = 'Module is available and imported.'
                }

                $result = [pscustomobject]@{
                    Name            = $moduleName
                    IsAvailable     = $isAvailable
                    MeetsVersion    = $meetsVersion
                    RequiredVersion = $requiredVersion
                    InstalledVersion = if ($latestModule) { [string]$latestModule.Version } else { $null }
                    Imported        = $imported
                    Status          = $status
                    Message         = $message
                }

                $results.Add($result)
            }
            catch {
                $result = [pscustomobject]@{
                    Name             = $moduleName
                    IsAvailable      = $false
                    MeetsVersion     = $false
                    RequiredVersion  = $MinimumVersion[$moduleName]
                    InstalledVersion = $null
                    Imported         = $false
                    Status           = 'Error'
                    Message          = $_.Exception.Message
                }

                $results.Add($result)
            }
        }
    }

    end {
        if (-not $PassThruOnly.IsPresent -and (Get-Command -Name Initialize-Logger -ErrorAction SilentlyContinue)) {
            foreach ($result in $results) {
                $logLevel = if ($result.IsAvailable -and $result.MeetsVersion) { 'Information' } else { 'Warning' }
                Initialize-Logger -LogLevel $logLevel -LogMessage "Module check: $($result.Name) - $($result.Status). $($result.Message)" -NoHostOutput | Out-Null
            }
        }

        $results
    }
}
