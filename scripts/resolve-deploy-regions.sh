#!/bin/bash
# Resolve deploy regions from config and validate manual region input.
# Writes deploy_regions_json and primary_region to OUTPUT_FILE (GITHUB_OUTPUT format).
#
# Usage: REGIONS_JSON='["eu-west-1"]' resolve-deploy-regions.sh <region_input> <default_region> <environment> [output_file]
#   region_input:  'all' or a specific region (e.g. eu-west-1)
#   default_region: Fallback when deploy.<env>.regions is empty (e.g. vars.AWS_REGION)
#   environment: Used in error message only
#   output_file: Default $GITHUB_OUTPUT
#
# Env: REGIONS_JSON - JSON array from parse-lambda-config.sh (deploy.<env>.regions)

set -e

REGION_INPUT="${1}"
DEFAULT_REGION="${2}"
ENVIRONMENT="${3}"
OUTPUT_FILE="${4:-$GITHUB_OUTPUT}"
REGIONS_JSON="${REGIONS_JSON:-[]}"

if [ -z "$REGION_INPUT" ] || [ -z "$DEFAULT_REGION" ]; then
  echo "Usage: REGIONS_JSON='...' resolve-deploy-regions.sh <region_input> <default_region> <environment> [output_file]"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  sudo apt-get update && sudo apt-get install -y jq
fi

if [ "$REGION_INPUT" = "all" ]; then
  if [ -z "$REGIONS_JSON" ] || [ "$REGIONS_JSON" = "[]" ]; then
    DEPLOY_REGIONS_JSON="[\"$DEFAULT_REGION\"]"
    PRIMARY_REGION="$DEFAULT_REGION"
  else
    DEPLOY_REGIONS_JSON="$REGIONS_JSON"
    PRIMARY_REGION=$(echo "$REGIONS_JSON" | jq -r '.[0]')
    if [ -z "$PRIMARY_REGION" ] || [ "$PRIMARY_REGION" = "null" ]; then
      PRIMARY_REGION="$DEFAULT_REGION"
    fi
  fi
else
  ALLOWED_JSON="$REGIONS_JSON"
  if [ -z "$ALLOWED_JSON" ] || [ "$ALLOWED_JSON" = "[]" ]; then
    ALLOWED_JSON="[\"$DEFAULT_REGION\"]"
  fi
  FOUND=$(echo "$ALLOWED_JSON" | jq -r --arg r "$REGION_INPUT" 'if index($r) != null then "true" else "false" end')
  if [ "$FOUND" != "true" ]; then
    echo "::error::Region '$REGION_INPUT' is not in deploy.${ENVIRONMENT}.regions (or default $DEFAULT_REGION). Allowed: $ALLOWED_JSON"
    exit 1
  fi
  DEPLOY_REGIONS_JSON="[\"$REGION_INPUT\"]"
  PRIMARY_REGION="$REGION_INPUT"
fi

echo "deploy_regions_json=$DEPLOY_REGIONS_JSON" >> "$OUTPUT_FILE"
echo "primary_region=$PRIMARY_REGION" >> "$OUTPUT_FILE"
