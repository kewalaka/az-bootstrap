BeforeAll {
    $ModuleName = 'az-bootstrap'
    $ModuleRoot = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath $ModuleName
    Import-Module -Name $ModuleRoot -Force
}

Describe 'DefaultLocation handling in Invoke-AzBootstrap' {
    BeforeAll {
        # Mock functions
        Mock -CommandName Test-GitHubCLI -ModuleName $ModuleName -MockWith { return $true }
        Mock -CommandName Get-AzCliContext -ModuleName $ModuleName -MockWith { 
            return @{
                SubscriptionId   = 'mock-subscription-id'
                SubscriptionName = 'mock-subscription'
                TenantId         = 'mock-tenant-id'
                UserName         = 'mock-user'
            }
        }
        
        # Set git username
        Mock -CommandName Invoke-Expression -ModuleName $ModuleName -ParameterFilter {
            $command -like 'gh repo create*'
        } -MockWith { 
            # Return success for gh repo create
            $global:LASTEXITCODE = 0
            return 
        }
        
        # Mock git command
        Mock -CommandName git -ModuleName $ModuleName -MockWith { 
            $global:LASTEXITCODE = 0
            return 
        }
        
        # Mock the GitHub user lookup
        $script:mockGhOutput = @"
github.com
  ✓ Logged in to github.com account test-user (oauth_token)
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: gho_***************************************
"@
        Mock -CommandName gh -ModuleName $ModuleName -MockWith { 
            return $script:mockGhOutput 
        }
        
        # Mock GitHub repository info
        Mock -CommandName Get-GitHubRepositoryInfo -ModuleName $ModuleName -MockWith { 
            return @{
                Owner = 'test-user'
                Repo  = 'test-repo'
            }
        }
        
        Mock -CommandName New-GitHubBranchRuleset -ModuleName $ModuleName -MockWith { }
        Mock -CommandName Add-AzBootstrapEnvironment -ModuleName $ModuleName -MockWith { }
        Mock -CommandName Test-Path -ModuleName $ModuleName -MockWith { return $false }
        Mock -CommandName Push-Location -ModuleName $ModuleName -MockWith { }
        Mock -CommandName Pop-Location -ModuleName $ModuleName -MockWith { }
        
        # Mock Select-String for the GitHub user detection
        Mock -CommandName Select-String -ModuleName $ModuleName -MockWith {
            $mockMatches = New-Object PSObject
            $mockGroup = New-Object PSObject
            Add-Member -InputObject $mockGroup -MemberType NoteProperty -Name "Value" -Value "test-user"
            $mockGroups = @($null, $mockGroup)
            Add-Member -InputObject $mockMatches -MemberType NoteProperty -Name "Matches" -Value @{Groups = $mockGroups}
            return $mockMatches
        }
    }

    Context 'When Location parameter is provided' {
        It 'Should use the provided Location parameter' {
            # Mock config function to return config with defaultLocation
            Mock -CommandName Get-AzBootstrapConfig -ModuleName $ModuleName -MockWith {
                return @{
                    defaultLocation = 'eastus'
                }
            }

            # This should use the provided Location
            { Invoke-AzBootstrap -TemplateRepoUrl 'test-template' -TargetRepoName 'test-repo' -Location 'westus' } | Should -Not -Throw
            
            # Verify Add-AzBootstrapEnvironment was called with westus, not eastus
            Should -Invoke -CommandName Add-AzBootstrapEnvironment -ModuleName $ModuleName -ParameterFilter {
                $Location -eq 'westus'
            }
        }
    }

    Context 'When Location parameter is not provided' {
        It 'Should use the defaultLocation from config' {
            # Mock config function to return config with defaultLocation
            Mock -CommandName Get-AzBootstrapConfig -ModuleName $ModuleName -MockWith {
                return @{
                    defaultLocation = 'eastus'
                }
            }

            # This should use defaultLocation from config
            { Invoke-AzBootstrap -TemplateRepoUrl 'test-template' -TargetRepoName 'test-repo' } | Should -Not -Throw
            
            # Verify Add-AzBootstrapEnvironment was called with eastus from the config
            Should -Invoke -CommandName Add-AzBootstrapEnvironment -ModuleName $ModuleName -ParameterFilter {
                $Location -eq 'eastus'
            }
        }

        It 'Should throw if no defaultLocation in config' {
            # Mock config function to return empty config
            Mock -CommandName Get-AzBootstrapConfig -ModuleName $ModuleName -MockWith {
                return @{}
            }

            # This should throw an error for missing location
            { Invoke-AzBootstrap -TemplateRepoUrl 'test-template' -TargetRepoName 'test-repo' } | 
                Should -Throw -ExpectedMessage "*Location is required*"
        }
    }
}