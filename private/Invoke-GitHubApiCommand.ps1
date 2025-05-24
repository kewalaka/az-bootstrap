function Invoke-GitHubApiCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Method,
        
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [hashtable]$Headers = @{},
        
        [object]$Body,
        
        [string]$InputFile,
        
        [string[]]$AdditionalArgs = @()
    )
    
    $cmd = @("gh", "api", "-X", $Method, $Endpoint)
    
    # Add standard headers
    $cmd += @("-H", "Accept: application/vnd.github+json")
    $cmd += @("-H", "X-GitHub-Api-Version: 2022-11-28")
    
    # Add custom headers
    foreach ($headerName in $Headers.Keys) {
        $cmd += @("-H", "$headerName`: $($Headers[$headerName])")
    }
    
    # Add body if provided
    if ($Body) {
        if ($Body -is [string]) {
            $cmd += @("-f", $Body)
        } else {
            # Assume it's an object that needs to be serialized
            $tempFile = New-TemporaryFile
            $Body | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8
            $cmd += @("--input", $tempFile)
        }
    }
    
    # Add input file if provided
    if ($InputFile) {
        $cmd += @("--input", $InputFile)
    }
    
    # Add additional arguments
    $cmd += $AdditionalArgs
    
    try {
        return Invoke-GitHubCliCommand -Command $cmd
    }
    finally {
        # Clean up temp files
        if ($Body -and $Body -isnot [string] -and $tempFile -and (Test-Path $tempFile)) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
