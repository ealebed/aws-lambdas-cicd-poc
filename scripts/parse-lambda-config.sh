#!/bin/bash
# Parse lambda-config.yaml and output GitHub Actions outputs
# Usage: parse-lambda-config.sh <lambda_path> <lambda_name> [output_file] [environment]
#
# Arguments:
#   lambda_path: Path to the Lambda function directory
#   lambda_name: Default Lambda name (folder name)
#   output_file: Path to GitHub Actions output file (default: $GITHUB_OUTPUT)
#   environment: Optional. When set, reads deploy.<env>.regions and outputs regions_json, primary_region

set -e

LAMBDA_PATH="${1}"
LAMBDA_NAME="${2}"
OUTPUT_FILE="${3:-$GITHUB_OUTPUT}"
ENVIRONMENT="${4:-}"

if [ -z "$LAMBDA_PATH" ] || [ -z "$LAMBDA_NAME" ]; then
  echo "Usage: parse-lambda-config.sh <lambda_path> <lambda_name> [output_file] [environment]"
  exit 1
fi

CONFIG_FILE="${LAMBDA_PATH}/lambda-config.yaml"

# Install yq if not available
if ! command -v yq &> /dev/null; then
  wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  chmod +x /usr/local/bin/yq
fi

# Install jq if not available
if ! command -v jq &> /dev/null; then
  sudo apt-get update && sudo apt-get install -y jq
fi

if [ -f "$CONFIG_FILE" ]; then
  # Basic configuration
  FUNCTION_NAME=$(yq eval ".lambda.name // \"${LAMBDA_NAME}\"" "$CONFIG_FILE")
  DESCRIPTION=$(yq eval '.lambda.description // ""' "$CONFIG_FILE")
  MEMORY_SIZE=$(yq eval '.lambda.memory_size // 256' "$CONFIG_FILE")
  TIMEOUT=$(yq eval '.lambda.timeout // 30' "$CONFIG_FILE")
  EPHEMERAL_STORAGE=$(yq eval '.lambda.ephemeral_storage // 512' "$CONFIG_FILE")
  ARCHITECTURES=$(yq eval '.lambda.architectures // "arm64"' "$CONFIG_FILE")
  PUBLISH=$(yq eval '.lambda.publish // true' "$CONFIG_FILE")

  echo "function_name=$FUNCTION_NAME" >> "$OUTPUT_FILE"
  echo "description=$DESCRIPTION" >> "$OUTPUT_FILE"
  echo "memory_size=$MEMORY_SIZE" >> "$OUTPUT_FILE"
  echo "timeout=$TIMEOUT" >> "$OUTPUT_FILE"
  echo "ephemeral_storage=$EPHEMERAL_STORAGE" >> "$OUTPUT_FILE"
  echo "architectures=$ARCHITECTURES" >> "$OUTPUT_FILE"
  echo "publish=$PUBLISH" >> "$OUTPUT_FILE"

  # Environment variables
  ENV_VARS=$(yq eval -o=json '.lambda.environment.variables // {}' "$CONFIG_FILE" 2>/dev/null || echo '{}')
  echo "env_vars=$(echo "$ENV_VARS" | jq -c '.')" >> "$OUTPUT_FILE"

  # Tags
  TAGS=$(yq eval -o=json '.lambda.tags // {}' "$CONFIG_FILE" 2>/dev/null || echo '{}')
  echo "config_tags=$(echo "$TAGS" | jq -c '.')" >> "$OUTPUT_FILE"

  # Optional configurations (as JSON strings)
  VPC_CONFIG=$(yq eval -o=json '.lambda.vpc_config // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$VPC_CONFIG" != "null" ] && [ "$VPC_CONFIG" != "{}" ]; then
    echo "vpc_config=$(echo "$VPC_CONFIG" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  DEAD_LETTER_CONFIG=$(yq eval -o=json '.lambda.dead_letter_config // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$DEAD_LETTER_CONFIG" != "null" ] && [ "$DEAD_LETTER_CONFIG" != "{}" ]; then
    echo "dead_letter_config=$(echo "$DEAD_LETTER_CONFIG" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  KMS_KEY_ARN=$(yq eval '.lambda.kms_key_arn // ""' "$CONFIG_FILE")
  if [ -n "$KMS_KEY_ARN" ]; then
    echo "kms_key_arn=$KMS_KEY_ARN" >> "$OUTPUT_FILE"
  fi

  TRACING_CONFIG=$(yq eval -o=json '.lambda.tracing_config // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$TRACING_CONFIG" != "null" ] && [ "$TRACING_CONFIG" != "{}" ]; then
    echo "tracing_config=$(echo "$TRACING_CONFIG" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  FILE_SYSTEM_CONFIGS=$(yq eval -o=json '.lambda.file_system_configs // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$FILE_SYSTEM_CONFIGS" != "null" ] && [ "$FILE_SYSTEM_CONFIGS" != "[]" ]; then
    echo "file_system_configs=$(echo "$FILE_SYSTEM_CONFIGS" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  IMAGE_CONFIG=$(yq eval -o=json '.lambda.image_config // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$IMAGE_CONFIG" != "null" ] && [ "$IMAGE_CONFIG" != "{}" ]; then
    echo "image_config=$(echo "$IMAGE_CONFIG" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  SNAP_START=$(yq eval -o=json '.lambda.snap_start // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$SNAP_START" != "null" ] && [ "$SNAP_START" != "{}" ]; then
    echo "snap_start=$(echo "$SNAP_START" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  LOGGING_CONFIG=$(yq eval -o=json '.lambda.logging_config // null' "$CONFIG_FILE" 2>/dev/null || echo 'null')
  if [ "$LOGGING_CONFIG" != "null" ] && [ "$LOGGING_CONFIG" != "{}" ]; then
    echo "logging_config=$(echo "$LOGGING_CONFIG" | jq -c '.')" >> "$OUTPUT_FILE"
  fi

  CODE_SIGNING_CONFIG_ARN=$(yq eval '.lambda.code_signing_config_arn // ""' "$CONFIG_FILE")
  if [ -n "$CODE_SIGNING_CONFIG_ARN" ]; then
    echo "code_signing_config_arn=$CODE_SIGNING_CONFIG_ARN" >> "$OUTPUT_FILE"
  fi

  # Lambda execution role ARN (required for Lambda to assume)
  ROLE_ARN=$(yq eval '.lambda.role_arn // ""' "$CONFIG_FILE")
  if [ -n "$ROLE_ARN" ]; then
    echo "role_arn=$ROLE_ARN" >> "$OUTPUT_FILE"
  fi

  # Deploy regions per environment (when environment is passed)
  if [ -n "$ENVIRONMENT" ]; then
    REGIONS_RAW=$(yq eval ".deploy.${ENVIRONMENT}.regions // []" "$CONFIG_FILE" 2>/dev/null || echo "[]")
    REGIONS_JSON=$(echo "$REGIONS_RAW" | yq eval -o=json '.' 2>/dev/null || echo "[]")
    REGIONS_JSON=$(echo "$REGIONS_JSON" | jq -c 'if type == "array" then . else [.] end' 2>/dev/null || echo "[]")
    echo "regions_json=$REGIONS_JSON" >> "$OUTPUT_FILE"
    PRIMARY=$(echo "$REGIONS_JSON" | jq -r 'if length > 0 then .[0] else "" end' 2>/dev/null || echo "")
    echo "primary_region=$PRIMARY" >> "$OUTPUT_FILE"
  fi
else
  # Defaults if no config file
  echo "function_name=${LAMBDA_NAME}" >> "$OUTPUT_FILE"
  echo "description=" >> "$OUTPUT_FILE"
  echo "memory_size=256" >> "$OUTPUT_FILE"
  echo "timeout=30" >> "$OUTPUT_FILE"
  echo "ephemeral_storage=512" >> "$OUTPUT_FILE"
  echo "architectures=arm64" >> "$OUTPUT_FILE"
  echo "publish=true" >> "$OUTPUT_FILE"
  echo "env_vars={}" >> "$OUTPUT_FILE"
  echo "config_tags={}" >> "$OUTPUT_FILE"
  if [ -n "$ENVIRONMENT" ]; then
    echo "regions_json=[]" >> "$OUTPUT_FILE"
    echo "primary_region=" >> "$OUTPUT_FILE"
  fi
fi
