#!/bin/bash
# Output image URI for a given region: use primary URI if same region, else pull from primary ECR and push to current region.
# Uses retries with backoff and verifies the image exists in the target region after push.
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

MAX_ATTEMPTS=3
BACKOFF_SECONDS=10

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
TARGET_URI="$REGISTRY/$ECR_REPO:${TAG}"

do_copy() {
  aws ecr get-login-password --region "$PRIMARY_REGION" | docker login --username AWS --password-stdin "$PRIMARY_REGISTRY"
  docker pull "$IMAGE_URI_PRIMARY"

  aws ecr get-login-password --region "$CURRENT_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
  docker tag "$IMAGE_URI_PRIMARY" "$TARGET_URI"
  docker push "$TARGET_URI"
}

verify_image_in_region() {
  aws ecr describe-images \
    --repository-name "$ECR_REPO" \
    --image-ids imageTag="$TAG" \
    --region "$CURRENT_REGION" \
    --query 'imageDetails[0].imageDigest' \
    --output text >/dev/null 2>&1
}

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  set +e
  do_copy
  copy_ok=$?
  set -e
  if [ "$copy_ok" -eq 0 ]; then
    if verify_image_in_region; then
      echo "uri=$TARGET_URI" >> "$OUTPUT_FILE"
      exit 0
    fi
    echo "::warning::Push reported success but image not found in $CURRENT_REGION (attempt $attempt/$MAX_ATTEMPTS)"
  else
    echo "::warning::ECR copy attempt $attempt/$MAX_ATTEMPTS failed"
  fi
  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    echo "Retrying in ${BACKOFF_SECONDS}s..."
    sleep "$BACKOFF_SECONDS"
    BACKOFF_SECONDS=$((BACKOFF_SECONDS * 2))
  fi
  attempt=$((attempt + 1))
done

echo "::error::ECR copy failed after $MAX_ATTEMPTS attempts (primary=$PRIMARY_REGION, target=$CURRENT_REGION, repo=$ECR_REPO, tag=$TAG)"
exit 1
