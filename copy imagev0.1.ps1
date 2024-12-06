# Variables
$acrStaging = "acrstagingl276ysr6kr3lu"
$acrAgent = "acragentl276ysr6kr3lu"
$sourceImage = "agents/docker-agent"
$sourceTag = "latest"
$targetImage = "agents/docker-agent"
$targetTag = "latest"

# Check for vulnerabilities in the source image
$vulnerabilities = az acr repository show-manifests --name $acrStaging --repository $sourceImage --query "[?contains(tags, '$sourceTag')].digest" -o tsv | ForEach-Object { az acr repository show --name $acrStaging --image "${sourceImage}@$_" --query "scanResults.vulnerabilities" -o tsv }

# If no vulnerabilities are found, copy the image to the target ACR
if (-not $vulnerabilities) {
    az acr import --name $acrAgent --source "$acrStaging.azurecr.io/${sourceImage}:$sourceTag" --image "${targetImage}:$targetTag"
    Write-Output "Image copied successfully."
} else {
    Write-Output "Vulnerabilities found in the image. Not copying."
}