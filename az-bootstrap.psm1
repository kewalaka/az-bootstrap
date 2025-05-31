# Import all public functions
Get-ChildItem -Path "$PSScriptRoot/public/*.ps1" | ForEach-Object { . $_.FullName }
# Import all private functions
Get-ChildItem -Path "$PSScriptRoot/private/*.ps1" | ForEach-Object { . $_.FullName }

New-Alias -Name iazb -Value Invoke-AzBootstrap -Description "Shorthand for Invoke-AzBootstrap"
Export-ModuleMember -Alias iazb