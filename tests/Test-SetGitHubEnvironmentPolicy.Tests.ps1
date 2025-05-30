Describe "Set-GitHubEnvironmentPolicy" {
    BeforeAll { 
        # Directly dot-source the functions we need
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
        . "$PSScriptRoot/../private/Invoke-GitHubCliCommand.ps1"
        . "$PSScriptRoot/../private/Invoke-GitHubApiCommand.ps1"
        . "$PSScriptRoot/../private/Set-GitHubEnvironmentPolicy.ps1"
        
        # Mock for dependencies
        Mock Write-BootstrapLog { }
        
        # Mock for Invoke-GitHubCliCommand
        Mock Invoke-GitHubCliCommand {
            param($Arguments)
            # Just return empty success for any CLI command
            return ""
        }
        
        # Mock for Invoke-GitHubApiCommand 
        Mock Invoke-GitHubApiCommand {
            param($Owner, $Repo, $Method, $Endpoint, $Body)
            # Return mock user ID when getting user info
            if ($Method -eq 'GET' -and $Endpoint -like '/users/*') {
                return '{"id": "12345"}'
            }
            return ""
        }
    }
    
    It "Calls gh api to set deployment branch policy with user reviewers" {
        # Act - this should not throw because we've mocked the dependencies
        { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -UserReviewers @("testreviewer") } | Should -Not -Throw
        
        # Assert - verify the mocks were called
        Should -Invoke Invoke-GitHubApiCommand -Exactly 2 -Scope It
        Should -Invoke Write-BootstrapLog -Exactly 2 -Scope It
    }

    It "Calls gh api to set deployment branch policy with no reviewers" {
        # Act - this should not throw because we've mocked the dependencies
        { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -UserReviewers @() -TeamReviewers @() } | Should -Not -Throw
        
        # Assert - verify the mocks were called
        Should -Invoke Invoke-GitHubCliCommand -Exactly 0 -Scope It
        Should -Invoke Write-BootstrapLog -Exactly 2 -Scope It
    }
}