Describe "Target Repository Name Parsing Integration" {
    BeforeAll {
        # Import just the parsing function
        . "$PSScriptRoot/../private/Resolve-TargetRepositoryInfo.ps1"
        
        # Mock gh command for owner detection
        Mock gh { return "Logged in to github.com account testuser (oauth_token)" }
    }
    
    Context "Resolve-TargetRepositoryInfo functionality" {
        It "Should handle owner/repo format correctly" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myorg/myrepo"
            
            $result.Owner | Should -Be "myorg"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "ParsedFromTarget"
        }
        
        It "Should use provided GitHubOwner for simple repo name" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myrepo" -GitHubOwner "providedowner"
            
            $result.Owner | Should -Be "providedowner"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "ProvidedOwner"
        }
        
        It "Should detect owner from gh CLI when not provided" {
            $result = Resolve-TargetRepositoryInfo -TargetRepoName "myrepo"
            
            $result.Owner | Should -Be "testuser"
            $result.Repo | Should -Be "myrepo"
            $result.Source | Should -Be "DetectedOwner"
        }
        
        It "Should reject conflicting owner specifications" {
            { Resolve-TargetRepositoryInfo -TargetRepoName "myorg/myrepo" -GitHubOwner "differentorg" } | Should -Throw "*Conflicting owner specification*"
        }
    }
}