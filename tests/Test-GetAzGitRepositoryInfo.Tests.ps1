Describe "Get-AzGitRepositoryInfo" {
    BeforeAll { 
        # Import the module
        Import-Module "$PSScriptRoot/../az-bootstrap.psd1" -Force
    }

    # Use InModuleScope to access private functions
    InModuleScope 'az-bootstrap' {
        It "Returns repo info from git remote" {
            # Mock git
            Mock git { "origin https://github.com/owner/repo.git (fetch)" }
            $result = Get-AzGitRepositoryInfo
            $result.RemoteUrl | Should -Be "https://github.com/owner/repo.git"
            $result.Owner | Should -Be "owner"
            $result.Repo | Should -Be "repo"
        }

        It "Returns repo info from Codespaces env" {
            # Mock git to return nothing, but set environment variables
            Mock git { $null }
            $env:GITHUB_SERVER_URL = "https://github.com"
            $env:GITHUB_REPOSITORY = "owner/repo"
            $result = Get-AzGitRepositoryInfo
            $result.RemoteUrl | Should -Be "https://github.com/owner/repo"
            $result.Owner | Should -Be "owner"
            $result.Repo | Should -Be "repo"
            # Clean up
            $env:GITHUB_SERVER_URL = $null
            $env:GITHUB_REPOSITORY = $null
        }

        It "Returns null if no info available" {
            # Mock git to return nothing, and no env vars
            Mock git { $null }
            $env:GITHUB_SERVER_URL = $null
            $env:GITHUB_REPOSITORY = $null
            $result = Get-AzGitRepositoryInfo
            $result | Should -BeNullOrEmpty
        }
    }
}
