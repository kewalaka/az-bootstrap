function Write-BootstrapLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info',
        
        [switch]$NoPrefix
    )
    
    $prefix = if ($NoPrefix) { "" } else { "[az-bootstrap] " }
    
    switch ($Level) {
        'Success' {
            Write-Host -NoNewline "`u{2713} " -ForegroundColor Green
            Write-Host "$prefix$Message"
        }
        'Warning' {
            Write-Warning "$prefix$Message"
        }
        'Error' {
            Write-Error "$prefix$Message"
        }
        default {
            Write-Host "$prefix$Message" -ForegroundColor Cyan
        }
    }
}
