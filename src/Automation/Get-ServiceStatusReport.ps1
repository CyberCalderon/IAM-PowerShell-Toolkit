function Get-ServiceStatusReport {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name = @('*'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = @($env:COMPUTERNAME)
    )

    process {
        foreach ($computer in $ComputerName) {
            try {
                $services = if ($computer -eq $env:COMPUTERNAME -or $computer -eq 'localhost') {
                    Get-Service -Name $Name -ErrorAction Stop
                }
                else {
                    Invoke-Command -ComputerName $computer -ScriptBlock {
                        param($ServiceName)
                        Get-Service -Name $ServiceName
                    } -ArgumentList (,$Name) -ErrorAction Stop
                }

                foreach ($service in $services) {
                    [pscustomobject]@{
                        ComputerName = $computer
                        Name         = $service.Name
                        DisplayName  = $service.DisplayName
                        Status       = $service.Status
                        StartType    = $service.StartType
                        ServiceType  = $service.ServiceType
                    }
                }
            }
            catch {
                [pscustomobject]@{
                    ComputerName = $computer
                    Name         = $null
                    DisplayName  = $null
                    Status       = 'Error'
                    StartType    = $null
                    ServiceType  = $null
                    Error        = $_.Exception.Message
                }
            }
        }
    }
}
