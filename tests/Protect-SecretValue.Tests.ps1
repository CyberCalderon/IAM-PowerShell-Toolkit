Describe 'Protect-SecretValue' {
    . "$PSScriptRoot\..\src\Core\Protect-SecretValue.ps1"

    It 'redacts sensitive properties and preserves non-sensitive properties' {
        $inputObject = [pscustomobject]@{
            UserName     = 'admin'
            ClientSecret = 'abc123'
            TokenValue   = 'xyz789'
        }

        $result = $inputObject | Protect-SecretValue

        $result.UserName | Should Be 'admin'
        $result.ClientSecret | Should Be '[REDACTED]'
        $result.TokenValue | Should Be '[REDACTED]'
    }
}
