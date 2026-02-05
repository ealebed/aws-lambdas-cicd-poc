#!/bin/bash
# Output image URI for a given region: use primary URI if same region, else pull from primary ECR and push to current region.
# Uses retries for copy failures; after push, waits for ECR eventual consistency then verifies (verify retries without re-pushing).
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

MAX_COPY_ATTEMPTS=3
COPY_BACKOFF_SECONDS=10
# ECR describe-images is eventually consistent; wait after push before first verify (can take 1–2 min in some regions)
POST_PUSH_DELAY_SECONDS=45
MAX_VERIFY_ATTEMPTS=8
VERIFY_RETRY_DELAY_SECONDS=15
# If set (e.g. 1), when push succeeds but verify never passes, output URI anyway and exit 0 (with warning). Use if ECR stays eventually consistent too long.
SKIP_VERIFY_ON_PUSH_SUCCESS="${SKIP_VERIFY_ON_PUSH_SUCCESS:-}"

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

# Run describe-images and show real AWS output (for debugging when verify fails)
describe_images_stderr() {
  aws ecr describe-images \
    --repository-name "$ECR_REPO" \
    --image-ids imageTag="$TAG" \
    --region "$CURRENT_REGION" \
    --query 'imageDetails[0].imageDigest' \
    --output text 2>&1
}

# Retry only verification (no re-push). ECR is eventually consistent after push.
verify_with_retries() {
  echo "Waiting ${POST_PUSH_DELAY_SECONDS}s for ECR eventual consistency..."
  sleep "$POST_PUSH_DELAY_SECONDS"
  v=1
  while [ "$v" -le "$MAX_VERIFY_ATTEMPTS" ]; do
    if verify_image_in_region; then
      return 0
    fi
    echo "::warning::Image not yet visible in $CURRENT_REGION (verify $v/$MAX_VERIFY_ATTEMPTS)"
    if [ "$v" -lt "$MAX_VERIFY_ATTEMPTS" ]; then
      echo "Retrying verify in ${VERIFY_RETRY_DELAY_SECONDS}s..."
      sleep "$VERIFY_RETRY_DELAY_SECONDS"
    fi
    v=$((v + 1))
  done
  return 1
}

copy_attempt=1
copy_backoff=$COPY_BACKOFF_SECONDS
while [ "$copy_attempt" -le "$MAX_COPY_ATTEMPTS" ]; do
  set +e
  do_copy
  copy_ok=$?
  set -e
  if [ "$copy_ok" -eq 0 ]; then
    if verify_with_retries; then
      echo "uri=$TARGET_URI" >> "$OUTPUT_FILE"
      exit 0
    fi
    echo "::warning::Push succeeded but image still not visible after ${MAX_VERIFY_ATTEMPTS} verify attempts (copy attempt $copy_attempt/$MAX_COPY_ATTEMPTS)"
    echo "Last describe-images output:"
    describe_images_stderr || true
    if [ -n "$SKIP_VERIFY_ON_PUSH_SUCCESS" ]; then
      echo "::warning::SKIP_VERIFY_ON_PUSH_SUCCESS is set; proceeding with URI (image may be eventually consistent)."
      echo "uri=$TARGET_URI" >> "$OUTPUT_FILE"
      exit 0
    fi
  else
    echo "::warning::ECR copy attempt $copy_attempt/$MAX_COPY_ATTEMPTS failed"
  fi
  if [ "$copy_attempt" -lt "$MAX_COPY_ATTEMPTS" ]; then
    echo "Retrying copy in ${copy_backoff}s..."
    sleep "$copy_backoff"
    copy_backoff=$((copy_backoff * 2))
  fi
  copy_attempt=$((copy_attempt + 1))
done

echo "::error::ECR copy failed after $MAX_COPY_ATTEMPTS attempts (primary=$PRIMARY_REGION, target=$CURRENT_REGION, repo=$ECR_REPO, tag=$TAG)"
exit 1
