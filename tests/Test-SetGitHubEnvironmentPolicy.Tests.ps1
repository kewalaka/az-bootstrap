Describe "Set-GitHubEnvironmentPolicy" {
    BeforeAll { 
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force 
    }

    InModuleScope 'az-bootstrap' {
        It "Calls gh api to set deployment branch policy with user reviewers" {
            # Mock both Invoke-GitHubApiCommand and Write-BootstrapLog
            Mock Write-BootstrapLog { }
            Mock Invoke-GitHubApiCommand { 
                # Return mock user ID when getting user info
                if ($Method -eq 'GET' -and $Endpoint -like '/users/*') {
                    return '{"id": "12345"}'
                }
                return $null 
            }
            
            { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -UserReviewers @("testreviewer") } | Should -Not -Throw
            
            # Should call once for getting user ID and once for setting policy
            Should -Invoke Invoke-GitHubApiCommand -Exactly 2 -Scope It
            Should -Invoke Write-BootstrapLog -Exactly 2 -Scope It
        }

        It "Calls gh api to set deployment branch policy with no reviewers" {
            Mock Write-BootstrapLog { }
            Mock Invoke-GitHubApiCommand { return $null }
            
            { Set-GitHubEnvironmentPolicy -Owner "org" -Repo "repo" -EnvironmentName "APPLY" -UserReviewers @() -TeamReviewers @() } | Should -Not -Throw
            
            # Should only call once for setting policy (no user/team lookups needed)
            Should -Invoke Invoke-GitHubApiCommand -Exactly 1 -Scope It
            Should -Invoke Write-BootstrapLog -Exactly 2 -Scope It
        }
    }
}