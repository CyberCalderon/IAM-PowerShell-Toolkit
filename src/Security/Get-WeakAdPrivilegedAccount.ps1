function Get-WeakAdPrivilegedAccount {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 3650)]
        [int]$StaleDays = 90,

        [Parameter()]
        [datetime]$ReferenceDate = (Get-Date)
    )

    process {
        try {
            if (-not (Get-Command -Name Get-AdPrivilegedGroupMember -ErrorAction SilentlyContinue)) {
                $identityPath = Join-Path -Path $PWD -ChildPath 'src\Identity\Get-AdPrivilegedGroupMember.ps1'
                if (Test-Path -Path $identityPath -PathType Leaf) { . $identityPath }
            }

            $privilegedMembers = Get-AdPrivilegedGroupMember -Recursive -PassThruOnly
            foreach ($member in $privilegedMembers) {
                if ($member.ObjectClass -eq 'user' -and $member.SamAccountName) {
                    $user = Get-ADUser -Identity $member.SamAccountName -Properties Enabled, LastLogonDate, PasswordLastSet, PasswordNeverExpires -ErrorAction Stop
                    $findings = [System.Collections.Generic.List[string]]::new()
                    if (-not $user.Enabled) { $findings.Add('DisabledPrivilegedAccount') }
                    if ($user.PasswordNeverExpires) { $findings.Add('PasswordNeverExpires') }
                    if ($user.LastLogonDate -and $user.LastLogonDate -lt $ReferenceDate.AddDays(-$StaleDays)) { $findings.Add('StalePrivilegedAccount') }

                    if ($findings.Count -gt 0) {
                        [pscustomobject]@{
                            SamAccountName    = $user.SamAccountName
                            Name              = $user.Name
                            PrivilegedGroup   = $member.PrivilegedGroup
                            Enabled           = $user.Enabled
                            LastLogonDate     = $user.LastLogonDate
                            PasswordLastSet   = $user.PasswordLastSet
                            PasswordNeverExpires = $user.PasswordNeverExpires
                            Findings          = $findings -join ','
                        }
                    }
                }
            }
        }
        catch {
            throw "Weak privileged account report failed. $($_.Exception.Message)"
        }
    }
}
