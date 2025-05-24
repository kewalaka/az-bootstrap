# Import all public functions
Get-ChildItem -Path "$PSScriptRoot/public/*.ps1" | ForEach-Object { 
    Write-Verbose "Importing public function from: $($_.FullName)"
    . $_.FullName 
    # Export the function with the same name as file (minus extension)
    Export-ModuleMember -Function $_.BaseName
}

# Import all private functions
Get-ChildItem -Path "$PSScriptRoot/private/*.ps1" | ForEach-Object { 
    Write-Verbose "Importing private function from: $($_.FullName)"
    . $_.FullName 
}
