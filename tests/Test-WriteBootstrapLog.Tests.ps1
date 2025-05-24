Describe "Write-BootstrapLog" {
    BeforeAll { 
        # Import directly to make it available
        . "$PSScriptRoot/../private/Write-BootstrapLog.ps1"
    }
        It "Writes Info level message with prefix" {
            Mock Write-Host {}
            
            Write-BootstrapLog -Message "Test message"
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "[az-bootstrap] Test message"
            }
        }
        
        It "Writes Success level message with checkmark" {
            Mock Write-Host {}
            
            Write-BootstrapLog -Message "Success message" -Level Success
            
            Should -Invoke Write-Host -ParameterFilter { 
                $NoNewline -eq $true -and $ForegroundColor -eq 'Green' 
            }
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "[az-bootstrap] Success message" 
            }
        }
        
        It "Writes Warning level message" {
            Mock Write-Warning {}
            
            Write-BootstrapLog -Message "Warning message" -Level Warning
            
            Should -Invoke Write-Warning -ParameterFilter { 
                $Message -eq "[az-bootstrap] Warning message"
            }
        }
        
        It "Writes Error level message" {
            Mock Write-Error {}
            
            Write-BootstrapLog -Message "Error message" -Level Error
            
            Should -Invoke Write-Error -ParameterFilter { 
                $Message -eq "[az-bootstrap] Error message"
            }
        }
        
        It "Doesn't include prefix when NoPrefix is specified" {
            Mock Write-Host {}
            
            Write-BootstrapLog -Message "No prefix message" -NoPrefix
            
            Should -Invoke Write-Host -ParameterFilter { 
                $Object -eq "No prefix message"
            }
        }
}
