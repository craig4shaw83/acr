# Variables
$acrStaging = "acrstagingl276ysr6kr3lu"
$acrAgent = "acragentl276ysr6kr3lu"
$sourceImage = "samples/alpine"
$sourceTag = "latest"
$targetImage = "samples/alpineprod"
$targetTag = "latest"

# Construct the resource ID for the specific container image
$resourceId = "/subscriptions/<your-subscription-id>/resourceGroups/<your-resource-group>/providers/Microsoft.ContainerRegistry/registries/$acrStaging/repositories/$sourceImage/tags/$sourceTag"

# Query for vulnerabilities using Azure Resource Graph
$query = @"
SecurityResources
| where type == 'microsoft.security/assessments'
| where properties.displayName contains 'Azure registry container images should have vulnerabilities resolved'
| summarize by assessmentKey=name //the ID of the assessment
| join kind=inner (
    SecurityResources
    | where type == 'microsoft.security/assessments/subassessments'
    | extend assessmentKey = extract('.*assessments/(.+?)/.*',1, id)
) on assessmentKey
| where properties.resourceDetails.id == '$resourceId'
| project assessmentKey, subassessmentKey=name, id, parse_json(properties), resourceGroup, subscriptionId, tenantId
| extend description = properties.description, displayName = properties.displayName, resourceId = properties.resourceDetails.id, resourceSource = properties.resourceDetails.source, category = properties.category, severity = properties.status.severity, code = properties.status.code, timeGenerated = properties.timeGenerated, remediation = properties.remediation, impact = properties.impact, vulnId = properties.id, additionalData = properties.additionalData
"@

Write-Output "Running Azure Resource Graph query to check for vulnerabilities..."
$vulnerabilities = az graph query -q $query -o tsv

Write-Output "Query result: $vulnerabilities"

# If no vulnerabilities are found, copy the image to the target ACR
if (-not $vulnerabilities) {
    Write-Output "No vulnerabilities found. Copying the image..."
    az acr import --name $acrAgent --source "$acrStaging.azurecr.io/${sourceImage}:$sourceTag" --image "${targetImage}:$targetTag"
    Write-Output "Image copied successfully."
} else {
    Write-Output "Vulnerabilities found in the image. Not copying."
}