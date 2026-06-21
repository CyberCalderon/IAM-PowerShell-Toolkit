Describe 'UtilityBelt module' {
    It 'imports and exports expected commands' {
        Import-Module "$PSScriptRoot\..\UtilityBelt.psd1" -Force
        $commands = Get-Command -Module UtilityBelt | Select-Object -ExpandProperty Name

        $commands -contains 'Initialize-Logger' | Should Be $true
        $commands -contains 'Get-AdInventory' | Should Be $true
        $commands -contains 'Get-StaleAdComputer' | Should Be $true
        $commands -contains 'Get-IdentitySecuritySummary' | Should Be $true
    }
}
