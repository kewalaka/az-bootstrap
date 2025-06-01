Describe "Resolve-TargetRepositoryInfo" {
    BeforeAll {
        # Import the function being tested
        . "$PSScriptRoot/../private/Resolve-TargetRepositoryInfo.ps1"
        
        # Mock the gh command that retrieves the current user
        Mock -CommandName "gh" -MockWith {
            return "Logged in to github.com account testuser (oauth_token)"
        }
    }
    
    Context "When TargetRepoName contains owner/repo format" {
        It "Should parse owner and repo correctly" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myorg/myrepo"
            
            $result.Owner | Should -Be "myorg"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "ParsedFromTarget"
        }
        
        It "Should handle complex org and repo names" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "my-complex-org/my-repo-name"
            
            $result.Owner | Should -Be "my-complex-org"
            $result.Repo | Should -Be "my-repo-name"
            $result.Source | Should -Be "ParsedFromTarget"
        }
        
        It "Should throw error when GitHubOwner conflicts with parsed owner" {
            { Resolve-TargetRepositoryInfo -TargetRepoName "myorg/myrepo" -GitHubOwner "differentorg" } | Should -Throw "*Conflicting owner specification*"
        }
        
        It "Should work when GitHubOwner matches parsed owner" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myorg/myrepo" -GitHubOwner "myorg"
            
            $result.Owner | Should -Be "myorg"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "ParsedFromTarget"
        }
    }
    
    Context "When TargetRepoName is just repo name" {
        It "Should use provided GitHubOwner" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myrepo" -GitHubOwner "providedowner"
            
            $result.Owner | Should -Be "providedowner"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "ProvidedOwner"
        }
        
        It "Should detect owner from gh CLI when GitHubOwner not provided" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myrepo"
            
            $result.Owner | Should -Be "testuser"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "DetectedOwner"
        }
        
        It "Should throw error when cannot detect owner and none provided" {
            # Mock gh to return empty result
            Mock -CommandName "gh" -MockWith { return "" }
            
            { Resolve-TargetRepositoryInfo -TargetRepoName "myrepo" } | Should -Throw "*Could not determine GitHub owner*"
        }
    }
    
    Context "Edge cases" {
        It "Should not match multiple slashes" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "org/repo/extra" -GitHubOwner "testowner"
            
            $result.Owner | Should -Be "testowner"
            $result.Repo | Should -Be "org/repo/extra"
            $result.Source | Should -Be "ProvidedOwner"
        }
        
        It "Should not match empty parts" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "/myrepo" -GitHubOwner "testowner"
            
            $result.Owner | Should -Be "testowner"
            $result.Repo | Should -Be "/myrepo"
            $result.Source | Should -Be "ProvidedOwner"
        }
        
        It "Should not match empty repo name" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myorg/" -GitHubOwner "testowner"
            
            $result.Owner | Should -Be "testowner"
            $result.Repo | Should -Be "myorg/"
            $result.Source | Should -Be "ProvidedOwner"
        }
    }
}