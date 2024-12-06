@description('The location of the resources.')
param location string = 'northeurope'

@description('The SKU of the Azure Container Registry.')
param acrSku string = 'Basic'

@description('The source image name.')
param sourceImage string = 'agents/docker-agent'

@description('The source image tag.')
param sourceTag string = 'latest'

@description('The target image name.')
param targetImage string = 'agents/docker-agent'

@description('The target image tag.')
param targetTag string = 'latest'

targetScope = 'resourceGroup'

resource acrStaging 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'acrstaging${uniqueString(resourceGroup().id)}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource acrAgent 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'acragent${uniqueString(resourceGroup().id)}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource copyImageTask 'Microsoft.ContainerRegistry/registries/tasks@2019-06-01-preview' = {
  name: '${acrAgent.name}/copyImageTask'
  location: location
  properties: {
    step: {
      type: 'AzureCLI'
      contextPath: '/dev/null'
      scriptPath: 'copyImageScript.sh'
      arguments: [
        {
          name: 'acrStaging'
          value: acrStaging.name
        }
        {
          name: 'acrAgent'
          value: acrAgent.name
        }
        {
          name: 'sourceImage'
          value: sourceImage
        }
        {
          name: 'sourceTag'
          value: sourceTag
        }
        {
          name: 'targetImage'
          value: targetImage
        }
        {
          name: 'targetTag'
          value: targetTag
        }
      ]
    }
    status: 'Enabled'
    platform: {
      os: 'Linux'
    }
    agentConfiguration: {
      cpu: 2
    }
  }
}

resource copyImageScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'copyImageScript'
  location: location
  properties: {
    Kind: 'AzureCLI'
    azCliVersion: '2.0.80'
    scriptContent: '''
      #!/bin/bash

      # Variables
      acrStaging=$1
      acrAgent=$2
      sourceImage=$3
      sourceTag=$4
      targetImage=$5
      targetTag=$6

      # Query for vulnerabilities using Azure Resource Graph
      query="securityresources
      | where type == 'microsoft.security/assessments'
      | summarize by assessmentKey=name //the ID of the assessment
      | join kind=inner (
        securityresources
        | where type == 'microsoft.security/assessments/subassessments'
        | extend assessmentKey = extract('.*assessments/(.+?)/.*',1, id)
      ) on assessmentKey
      | where properties.additionalData.assessedResourceType == 'ContainerRegistryVulnerability'
      | extend status = properties.status.code
      | extend severity = properties.status.severity"

      echo "Running Azure Resource Graph query to check for vulnerabilities..."
      vulnerabilities=$(az graph query -q "$query" --query "data[?contains(properties.resourceDetails.id, '$acrStaging.azurecr.io/$sourceImage:$sourceTag')]" -o tsv)

      echo "Query result: $vulnerabilities"

      # If no vulnerabilities are found, copy the image to the target ACR
      if [ -z "$vulnerabilities" ]; then
          echo "No vulnerabilities found. Copying the image..."
          az acr import --name $acrAgent --source "$acrStaging.azurecr.io/$sourceImage:$sourceTag" --image "$targetImage:$targetTag"
          echo "Image copied successfully."
      else
          echo "Vulnerabilities found in the image. Not copying."
      fi
    '''
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}
