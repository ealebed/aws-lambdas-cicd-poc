#!/bin/bash
# Ensure ECR repository exists in the given region and apply lifecycle policy.
#
# Usage: ecr-ensure-repo.sh <repository_name> <region> [lifecycle_policy_path]
#   lifecycle_policy_path: Default scripts/ecr-lifecycle-policy.json (relative to repo root)

set -e

REPO_NAME="${1}"
REGION="${2}"
LIFECYCLE_POLICY="${3:-scripts/ecr-lifecycle-policy.json}"

if [ -z "$REPO_NAME" ] || [ -z "$REGION" ]; then
  echo "Usage: ecr-ensure-repo.sh <repository_name> <region> [lifecycle_policy_path]"
  exit 1
fi

aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" 2>/dev/null || \
  aws ecr create-repository --repository-name "$REPO_NAME" --region "$REGION"

if [ -f "$LIFECYCLE_POLICY" ]; then
  aws ecr put-lifecycle-policy \
    --repository-name "$REPO_NAME" \
    --lifecycle-policy-text "file://${LIFECYCLE_POLICY}" \
    --region "$REGION"
fi
