function Protect-SecretValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Mask = '[REDACTED]',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$SensitivePropertyName = @(
            'AccessToken',
            'ApiKey',
            'ClientSecret',
            'Credential',
            'Password',
            'RefreshToken',
            'Secret',
            'SecureString',
            'Token'
        )
    )

    process {
        try {
            if ($null -eq $InputObject) {
                return $null
            }

            if ($InputObject -is [string]) {
                return $InputObject
            }

            $protectedObject = [ordered]@{}
            $properties = $InputObject.PSObject.Properties

            foreach ($property in $properties) {
                $isSensitive = $false

                foreach ($sensitiveName in $SensitivePropertyName) {
                    if ($property.Name -like "*$sensitiveName*") {
                        $isSensitive = $true
                    }
                }

                if ($isSensitive) {
                    $protectedObject[$property.Name] = $Mask
                }
                else {
                    $protectedObject[$property.Name] = $property.Value
                }
            }

            [pscustomobject]$protectedObject
        }
        catch {
            throw "Unable to protect sensitive values. $($_.Exception.Message)"
        }
    }
}
