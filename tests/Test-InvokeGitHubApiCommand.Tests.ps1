Describe "Invoke-GitHubApiCommand" {
    BeforeAll { 
        # Import directly to make it available
        . "$PSScriptRoot/../private/Invoke-GitHubCliCommand.ps1"
        . "$PSScriptRoot/../private/Invoke-GitHubApiCommand.ps1"
    }
        It "Calls GitHub API with correct parameters" {
            Mock Invoke-GitHubCliCommand { "API Result" }
            
            $result = Invoke-GitHubApiCommand -Method "GET" -Endpoint "/user"
            
            Should -Invoke Invoke-GitHubCliCommand -ParameterFilter {
                $Command -contains "gh" -and
                $Command -contains "api" -and
                $Command -contains "-X" -and
                $Command -contains "GET" -and
                $Command -contains "/user"
            }
            
            $result | Should -Be "API Result"
        }
        
        It "Includes custom headers when provided" {
            Mock Invoke-GitHubCliCommand { "API Result" }
            
            $headers = @{
                "Custom-Header" = "Value"
            }
            
            Invoke-GitHubApiCommand -Method "GET" -Endpoint "/user" -Headers $headers
            
            Should -Invoke Invoke-GitHubCliCommand -ParameterFilter {
                $Command -contains "-H" -and
                $Command -contains "Custom-Header`: Value"
            }
        }
        
        It "Includes additional arguments when provided" {
            Mock Invoke-GitHubCliCommand { "API Result" }
            
            Invoke-GitHubApiCommand -Method "GET" -Endpoint "/user" -AdditionalArgs @("--arg1", "value1", "--arg2", "value2")
            
            Should -Invoke Invoke-GitHubCliCommand -ParameterFilter {
                $Command -contains "--arg1" -and
                $Command -contains "value1" -and
                $Command -contains "--arg2" -and
                $Command -contains "value2"
            }
        }
}
