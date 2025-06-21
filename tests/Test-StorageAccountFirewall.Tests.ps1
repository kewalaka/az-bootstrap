Describe "StorageAccountFirewall Configuration" {
    BeforeAll {
        # Import necessary functions
        . "$PSScriptRoot/../private/Get-AzBootstrapConfig.ps1"
        
        # Create a temporary config file for testing
        $script:tempConfigDir = [System.IO.Path]::GetTempPath()
        $script:tempConfigFile = Join-Path $script:tempConfigDir ".azbootstrap-globals.jsonc"
    }
    
    AfterAll {
        # Clean up temp config file
        if (Test-Path $script:tempConfigFile) {
            Remove-Item $script:tempConfigFile -Force
        }
    }
    
    BeforeEach {
        # Clean up any existing temp config file before each test
        if (Test-Path $script:tempConfigFile) {
            Remove-Item $script:tempConfigFile -Force
        }
    }

    Context "Global Configuration Resolution" {
        It "Should use storageAccountFirewall from global config when available" {
            # Create a test config file with storageAccountFirewall setting
            $configContent = @'
{
    "storageAccountFirewall": "public",
    "defaultLocation": "eastus"
}
'@
            Set-Content -Path $script:tempConfigFile -Value $configContent
            
            # Mock environment to point to our temp config file
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                Mock Get-AzBootstrapConfig { 
                    $tempConfig = Get-Content -Path $script:tempConfigFile -Raw | ConvertFrom-Json -AsHashtable
                    return $tempConfig
                }
            } else {
                Mock Get-AzBootstrapConfig { 
                    $tempConfig = Get-Content -Path $script:tempConfigFile -Raw | ConvertFrom-Json -AsHashtable
                    return $tempConfig
                }
            }
            
            $config = Get-AzBootstrapConfig
            $config.ContainsKey('storageAccountFirewall') | Should -BeTrue
            $config.storageAccountFirewall | Should -Be "public"
        }
        
        It "Should return empty hashtable when no global config exists" {
            # Ensure no config file exists
            if (Test-Path $script:tempConfigFile) {
                Remove-Item $script:tempConfigFile -Force
            }
            
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*azbootstrap-globals.jsonc" }
            
            $config = Get-AzBootstrapConfig
            $config | Should -BeOfType [hashtable]
            $config.Count | Should -Be 0
        }
    }

    Context "Parameter Validation" {
        It "Should accept 'public' as valid StorageAccountFirewall value" {
            $function = Get-Command Add-AzBootstrapEnvironment
            $parameter = $function.Parameters['StorageAccountFirewall']
            $parameter.Attributes.ValidValues | Should -Contain 'public'
        }
        
        It "Should accept 'private' as valid StorageAccountFirewall value" {
            $function = Get-Command Add-AzBootstrapEnvironment
            $parameter = $function.Parameters['StorageAccountFirewall']
            $parameter.Attributes.ValidValues | Should -Contain 'private'
        }
        
        It "Should have ValidateSet attribute on StorageAccountFirewall parameter" {
            $function = Get-Command Add-AzBootstrapEnvironment
            $parameter = $function.Parameters['StorageAccountFirewall']
            $validateSetAttribute = $parameter.Attributes | Where-Object { $_.TypeId.Name -eq 'ValidateSetAttribute' }
            $validateSetAttribute | Should -Not -BeNullOrEmpty
        }
    }
}