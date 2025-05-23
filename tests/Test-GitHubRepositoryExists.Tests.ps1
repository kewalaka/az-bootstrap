Describe "Test-GitHubRepositoryExists" {
    BeforeAll {
        # Load the module and functions
        $modulePath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        . "$modulePath\private\Test-GitHubRepositoryExists.ps1"
        . "$modulePath\private\Invoke-GitHubCliCommand.ps1"
    }

    Context "When testing GitHub repository existence" {
        It "Should return true when repository exists" {
            # Arrange
            Mock Invoke-GitHubCliCommand -Verifiable -MockWith { return "test-repo" }

            # Act
            $result = Test-GitHubRepositoryExists -Owner "testowner" -Repo "test-repo"

            # Assert
            $result | Should -BeTrue
            Should -InvokeVerifiable
        }

        It "Should return false when repository does not exist" {
            # Arrange
            Mock Invoke-GitHubCliCommand -Verifiable -MockWith { throw "Not Found" }

            # Act
            $result = Test-GitHubRepositoryExists -Owner "testowner" -Repo "nonexistent-repo"

            # Assert
            $result | Should -BeFalse
            Should -InvokeVerifiable
        }

        It "Should return false when the repository name doesn't match" {
            # Arrange
            Mock Invoke-GitHubCliCommand -Verifiable -MockWith { return "different-repo" }

            # Act
            $result = Test-GitHubRepositoryExists -Owner "testowner" -Repo "test-repo"

            # Assert
            $result | Should -BeFalse
            Should -InvokeVerifiable
        }
    }
}