Describe "Test-GitHubRepositoryExists" {
    BeforeAll { 
        # Import the module
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    InModuleScope 'az-bootstrap' {
        Context "When testing GitHub repository existence" {
            BeforeAll {
                # Define the mock outside of the It blocks to ensure it's available               
                Mock Write-BootstrapLog {
                    param(
                        [string]$Message,
                        [string]$Level,
                        [switch]$NoPrefix
                    )
                    # Do nothing
                }
            }

            It "Should return true when repository exists" {
                Mock Invoke-GitHubCliCommand { "test-repo" }

                # Act
                $result = Test-GitHubRepositoryExists -Owner "testowner" -Repo "test-repo"

                # Assert
                $result | Should -BeTrue
                Should -Invoke Invoke-GitHubCliCommand -Exactly 1 -Scope It
            }

            It "Should return false when repository does not exist" {
                Mock Invoke-GitHubCliCommand { throw "Not Found" }

                # Act
                $result = Test-GitHubRepositoryExists -Owner "testowner" -Repo "nonexistent-repo"

                # Assert
                $result | Should -BeFalse
                Should -Invoke Invoke-GitHubCliCommand -Exactly 1 -Scope It
            }

            It "Should return false when the repository name doesn't match" {
                Mock Invoke-GitHubCliCommand { "different-repo" }

                # Act
                $result = Test-GitHubRepositoryExists -Owner "testowner" -Repo "test-repo"

                # Assert
                $result | Should -BeFalse
                Should -Invoke Invoke-GitHubCliCommand -Exactly 1 -Scope It
            }
        }
    }
}