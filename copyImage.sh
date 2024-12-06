#!/bin/bash

# Variables
acrStaging="acrstagingl276ysr6kr3lu"
acrAgent="acragentl276ysr6kr3lu "
sourceImage="samples/nginx"
sourceTag="latest"
targetImage="samples/nginxprod"
targetTag="latest"

# Check for vulnerabilities in the source image
vulnerabilities=$(az acr repository show-manifests --name $acrStaging --repository $sourceImage --query "[?tags[?contains(@, '$sourceTag')]].tags" -o tsv | xargs -I {} az acr repository show --name $acrStaging --image $sourceImage:{} --query "scanResults.vulnerabilities" -o tsv)

# If no vulnerabilities are found, copy the image to the target ACR
if [ -z "$vulnerabilities" ]; then
  az acr import --name $acrAgent --source $acrStaging.azurecr.io/$sourceImage:$sourceTag --image $targetImage:$targetTag
  echo "Image copied successfully."
else
  echo "Vulnerabilities found in the image. Not copying."
fi