function Remove-AzDeploymentStack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StackName,
        
        [Parameter(Mandatory = $false)]
        [string]$Location = "australiaeast"
    )
    
    try {
        Write-BootstrapLog "Deleting Azure deployment stack '$StackName'..."
        
        $azCliArgs = @(
            'stack', 'sub', 'delete',
            '--name', $StackName,
            '--action-on-unmanage', 'deleteResources',
            '--yes'  # Automatically confirm deletion
        )
        
        Write-Verbose "[az-bootstrap] Executing: az $($azCliArgs -join ' ')"
        
        $stdoutfile = New-TemporaryFile
        $stderrfile = New-TemporaryFile
        $process = Start-Process "az" -ArgumentList $azCliArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutfile -RedirectStandardError $stderrfile
        $stdout = Get-Content $stdoutfile -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $stderrfile -Raw -ErrorAction SilentlyContinue
        Remove-Item $stdoutfile, $stderrfile -ErrorAction SilentlyContinue
        
        if ($process.ExitCode -ne 0) {
            # Handle case where stack doesn't exist gracefully
            if ($stderr -match "StackNotFound" -or $stderr -match "not found" -or $stderr -match "does not exist") {
                Write-Warning "Azure deployment stack '$StackName' not found (may have already been removed)."
                return
            }
            
            Write-BootstrapLog "Failed to delete Azure deployment stack '$StackName'. Exit Code: $($process.ExitCode)" -Level Error
            Write-BootstrapLog "Standard Error: $stderr" -Level Error
            Write-BootstrapLog "Standard Output: $stdout" -Level Error
            throw "Failed to delete Azure deployment stack '$StackName'."
        }
        
        Write-BootstrapLog "Azure deployment stack '$StackName' deleted successfully." -Level Success
    }
    catch {
        Write-Error "Failed to delete Azure deployment stack '$StackName': $_"
        throw
    }
}