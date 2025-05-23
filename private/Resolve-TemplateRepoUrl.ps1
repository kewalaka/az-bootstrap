function Resolve-TemplateRepoUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateRepoUrl
    )
    
    # If it's already a full URL, return as-is
    if ($TemplateRepoUrl -match '^https?://') {
        Write-Verbose "Template repo URL is already a full URL: $TemplateRepoUrl"
        return $TemplateRepoUrl
    }
    
    # Try to resolve as an alias from global config
    $config = Get-AzBootstrapConfig
    
    if ($config.ContainsKey('templateAliases') -and $config.templateAliases.ContainsKey($TemplateRepoUrl)) {
        $resolvedUrl = $config.templateAliases[$TemplateRepoUrl]
        Write-Verbose "Resolved template alias '$TemplateRepoUrl' to '$resolvedUrl'"
        return $resolvedUrl
    }
    
    # If not found in aliases, treat as a potential GitHub repo shorthand (owner/repo)
    if ($TemplateRepoUrl -match '^[^/]+/[^/]+$') {
        $resolvedUrl = "https://github.com/$TemplateRepoUrl"
        Write-Verbose "Treating '$TemplateRepoUrl' as GitHub shorthand, resolved to '$resolvedUrl'"
        return $resolvedUrl
    }
    
    # If we can't resolve it, return as-is and let the calling function handle any errors
    Write-Verbose "Could not resolve template '$TemplateRepoUrl' as alias or shorthand, returning as-is"
    return $TemplateRepoUrl
}