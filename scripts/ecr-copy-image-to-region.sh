#!/bin/bash
# Output image URI for a given region: use primary URI if same region, else pull from primary ECR and push to current region.
#
# Usage: ecr-copy-image-to-region.sh <primary_region> <image_uri_primary> <tag> <ecr_repo_name> <current_region> <aws_account_id> [output_file]
# Output: uri=<image_uri>

set -e

PRIMARY_REGION="${1}"
IMAGE_URI_PRIMARY="${2}"
TAG="${3}"
ECR_REPO="${4}"
CURRENT_REGION="${5}"
AWS_ACCOUNT_ID="${6}"
OUTPUT_FILE="${7:-$GITHUB_OUTPUT}"

if [ -z "$PRIMARY_REGION" ] || [ -z "$IMAGE_URI_PRIMARY" ] || [ -z "$ECR_REPO" ] || [ -z "$CURRENT_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "Usage: ecr-copy-image-to-region.sh <primary_region> <image_uri_primary> <tag> <ecr_repo_name> <current_region> <aws_account_id> [output_file]"
  exit 1
fi

if [ "$CURRENT_REGION" = "$PRIMARY_REGION" ]; then
  echo "uri=$IMAGE_URI_PRIMARY" >> "$OUTPUT_FILE"
  exit 0
fi

PRIMARY_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${PRIMARY_REGION}.amazonaws.com"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${CURRENT_REGION}.amazonaws.com"

aws ecr get-login-password --region "$PRIMARY_REGION" | docker login --username AWS --password-stdin "$PRIMARY_REGISTRY"
docker pull "$IMAGE_URI_PRIMARY"

aws ecr get-login-password --region "$CURRENT_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker tag "$IMAGE_URI_PRIMARY" "$REGISTRY/$ECR_REPO:${TAG}"
docker push "$REGISTRY/$ECR_REPO:${TAG}"

echo "uri=$REGISTRY/$ECR_REPO:${TAG}" >> "$OUTPUT_FILE"
