function Get-LocalAdministratorAudit {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = @($env:COMPUTERNAME)
    )

    process {
        foreach ($computer in $ComputerName) {
            try {
                $groupName = 'Administrators'
                $members = if ($computer -eq $env:COMPUTERNAME -or $computer -eq 'localhost') {
                    Get-LocalGroupMember -Group $groupName -ErrorAction Stop
                }
                else {
                    Invoke-Command -ComputerName $computer -ScriptBlock {
                        Get-LocalGroupMember -Group 'Administrators'
                    } -ErrorAction Stop
                }

                foreach ($member in $members) {
                    [pscustomobject]@{
                        ComputerName = $computer
                        GroupName    = $groupName
                        Name         = $member.Name
                        ObjectClass  = $member.ObjectClass
                        PrincipalSource = $member.PrincipalSource
                    }
                }
            }
            catch {
                [pscustomobject]@{
                    ComputerName = $computer
                    GroupName    = 'Administrators'
                    Name         = $null
                    ObjectClass  = $null
                    PrincipalSource = $null
                    Error        = $_.Exception.Message
                }
            }
        }
    }
}
