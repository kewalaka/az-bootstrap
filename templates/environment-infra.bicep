targetScope = 'subscription'

@description('Name of the Resource Group to create.')
param resourceGroupName string

@description('Location for all resources.')
param location string

@description('Name of the plan User Assigned Identity to create (used for plan, and apply if separate apply MI is not created).')
param planManagedIdentityName string

@description('GitHub Owner for federated credential. Should be passed as lowercase.')
param gitHubOwner string

@description('GitHub Repository name for federated credential. Should be passed as lowercase.')
param gitHubRepo string

@description('GitHub Environment name for the "plan" federated credential. Should be passed as lowercase.')
param gitHubPlanEnvironmentName string

@description('GitHub Environment name for the "apply" federated credential. Should be passed as lowercase.')
param gitHubApplyEnvironmentName string

@description('Name of the Storage Account to create. If not supplied, no storage account will be created.')
param terraformStateStorageAccountName string = ''

@description('Retention days for blob delete retention policy.')
param retentionDays int = 7

// @description('Set to true to create a separate Managed Identity specifically for the "apply" environment. If false, the primary MI will be used for both plan and apply.')
// param createSeparateApplyMI bool = true

@description('Name of the User Assigned Identity for the "apply" environment, if createSeparateApplyMI is true.')
param applyManagedIdentityName string = '${planManagedIdentityName}-apply'

module rg 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'rgDeploy-${resourceGroupName}'
  params: {
    name: resourceGroupName
    location: location
    tags: {
      managedBy: 'az-bootstrap'
      githubRepo: gitHubRepo
      githubEnvironment: gitHubApplyEnvironmentName
    }
  }
  scope: subscription()
}

// Primary Managed Identity (always created, used for 'plan' and potentially 'apply')
module planManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'miDeploy-${planManagedIdentityName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: planManagedIdentityName
    location: location
    federatedIdentityCredentials: [
      // Plan FIC always on primary MI
      {
        name: 'ghactions-${gitHubOwner}-${gitHubRepo}-${gitHubPlanEnvironmentName}-plan'
        audiences: ['api://AzureADTokenExchange']
        issuer: 'https://token.actions.githubusercontent.com'
        subject: 'repo:${gitHubOwner}/${gitHubRepo}:environment:${gitHubPlanEnvironmentName}'
      }
      {
        name: 'ghactions-${gitHubOwner}-${gitHubRepo}-${gitHubApplyEnvironmentName}-apply' // Ensure unique name if both exist
        audiences: ['api://AzureADTokenExchange']
        issuer: 'https://token.actions.githubusercontent.com'
        subject: 'repo:${gitHubOwner}/${gitHubRepo}:environment:${gitHubApplyEnvironmentName}'
        //condition: !createSeparateApplyMI // Conditionally create this FIC
      }
    ]
    tags: {
      managedBy: 'az-bootstrap'
      githubRepo: gitHubRepo
      githubEnvironment: gitHubPlanEnvironmentName
    }
  }
  dependsOn: [
    rg // Explicit dependency
  ]
}

// Managed Identity for 'apply'
module applyManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  // = if (createSeparateApplyMI) {
  name: 'miDeploy-${applyManagedIdentityName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: applyManagedIdentityName
    location: location
    federatedIdentityCredentials: [
      {
        name: 'ghactions-${gitHubOwner}-${gitHubRepo}-${gitHubApplyEnvironmentName}'
        audiences: ['api://AzureADTokenExchange']
        issuer: 'https://token.actions.githubusercontent.com'
        subject: 'repo:${gitHubOwner}/${gitHubRepo}:environment:${gitHubApplyEnvironmentName}'
      }
    ]
    tags: {
      managedBy: 'az-bootstrap'
      githubRepo: gitHubRepo
      githubEnvironment: gitHubApplyEnvironmentName
    }
  }
  dependsOn: [
    rg // Explicit dependency
  ]
}

var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var rbacAdminRoleDefinitionId = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
var readerRoleDefinitionId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

module planMiReaderRbac './rbac.bicep' = {
  name: 'planMiReaderRbacDeploy'
  scope: resourceGroup(resourceGroupName)
  params: {
    principalId: planManagedIdentity.outputs.principalId
    roleDefinitionIdOrName: readerRoleDefinitionId
  }
}

module applyMiContributorRbac './rbac.bicep' = {
  name: 'applyMiContributorRbacDeploy'
  scope: resourceGroup(resourceGroupName)
  params: {
    principalId: applyManagedIdentity.outputs.principalId
    roleDefinitionIdOrName: contributorRoleDefinitionId
  }
}

module applyMiRbacAdmin './rbac.bicep' = {
  name: 'applyMiRbacAdminDeploy'
  scope: resourceGroup(resourceGroupName)
  params: {
    principalId: applyManagedIdentity.outputs.principalId
    roleDefinitionIdOrName: rbacAdminRoleDefinitionId
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.20.0' = if (!empty(terraformStateStorageAccountName)) {
  name: 'tfstorage-${uniqueString(terraformStateStorageAccountName)}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: terraformStateStorageAccountName
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: false
    blobServices: {
      versioning: {
        enabled: true
      }
      deleteRetentionPolicy: {
        enabled: true
        days: retentionDays
      }
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicy: {
        enabled: true
        days: 10
      }
      containers: [
        {
          name: 'tfstate'
          publicAccess: 'None'
          roleAssignments: [
            {
              principalId: planManagedIdentity.outputs.principalId
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
            }
            {
              principalId: applyManagedIdentity.outputs.principalId
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
            }
          ]
        }
        {
          name: 'tfartifact'
          publicAccess: 'None'
          roleAssignments: [
            {
              principalId: planManagedIdentity.outputs.principalId
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
            }
            {
              principalId: applyManagedIdentity.outputs.principalId
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
            }
          ]
        }
      ]
    }
    tags: {
      managedBy: 'az-bootstrap'
      githubRepo: gitHubRepo
      githubEnvironment: gitHubApplyEnvironmentName
    }
  }
}

// Outputs
@description('Resource ID of the created Resource Group.')
output resourceGroupId string = rg.outputs.resourceId

@description('Name of the created Resource Group.')
output resourceGroupName string = rg.outputs.name

@description('Client ID of the Plan Managed Identity.')
output planManagedIdentityClientId string = planManagedIdentity.outputs.clientId

@description('Client ID of the Plan Managed Identity.')
output applyManagedIdentityClientId string = applyManagedIdentity.outputs.clientId

@description('Resource ID of the Terraform State storage account.')
output terraformStateStorageAccountId string = !empty(terraformStateStorageAccountName) ? storageAccount.outputs.resourceId : ''

// @description('Resource ID of the Plan Managed Identity.')
// output planManagedIdentityResourceId string = planManagedIdentity.outputs.resourceId

// @description('Resource ID of the Apply Managed Identity.')
// output applyManagedIdentityResourceId string = applyManagedIdentity.outputs.resourceId

// @description('Principal ID of the Apply-Specific Managed Identity (if created).')
// output applyManagedIdentityPrincipalId string = createSeparateApplyMI ? applyManagedIdentity.outputs.principalId : ''

// @description('Client ID of the Apply-Specific Managed Identity (if created).')
// output applyManagedIdentityClientId string = createSeparateApplyMI ? applyManagedIdentity.outputs.clientId : ''

// @description('Resource ID of the Apply-Specific Managed Identity (if created).')
// output applyManagedIdentityResourceId string = createSeparateApplyMI ? applyManagedIdentity.outputs.resourceId : ''
