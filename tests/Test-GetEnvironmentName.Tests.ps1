Describe "Get-EnvironmentName" {
    BeforeAll { 
        # Import directly to make it available
        . "$PSScriptRoot/../private/Get-EnvironmentName.ps1"
    }
        It "Returns correctly formatted plan environment name" {
            $result = Get-EnvironmentName -EnvironmentName "dev" -Type "plan"
            $result | Should -Be "dev-iac-plan"
        }
        
        It "Returns correctly formatted apply environment name" {
            $result = Get-EnvironmentName -EnvironmentName "prod" -Type "apply"
            $result | Should -Be "prod-iac-apply"
        }
        
        It "Returns override when provided" {
            $result = Get-EnvironmentName -EnvironmentName "test" -Type "plan" -Override "custom-env"
            $result | Should -Be "custom-env"
        }
}
