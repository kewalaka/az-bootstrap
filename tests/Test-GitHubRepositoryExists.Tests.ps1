Describe "Test-GitHubRepositoryExists" {
    BeforeAll { 
        # Dot source the needed private function
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
        . "$PSScriptRoot/../private/Invoke-GitHubCliCommand.ps1"
        . "$PSScriptRoot/../private/Test-GitHubRepositoryExists.ps1"
        
        # Mock for dependencies
        Mock Write-BootstrapLog { }
    }

    Context "When testing GitHub repository existence" {
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