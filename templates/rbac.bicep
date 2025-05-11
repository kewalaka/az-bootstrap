@description('The principal ID to assign the role to.')
param principalId string

@description('The name or ID of the role definition to assign. e.g., "Contributor", "Reader", or a full GUID.')
param roleDefinitionIdOrName string

@description('A unique name for the role assignment. A GUID is recommended.')
param roleAssignmentName string = guid(principalId, roleDefinitionIdOrName)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIdOrName)
    principalId: principalId
    principalType: 'ServicePrincipal' // Assuming Managed Identities
  }
}

@description('The resource ID of the created role assignment.')
output roleAssignmentId string = roleAssignment.id
