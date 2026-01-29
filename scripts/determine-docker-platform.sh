#!/bin/bash
# Read lambda-config.yaml and output Docker platform (linux/amd64 or linux/arm64).
#
# Usage: determine-docker-platform.sh <lambda_path> [output_file]
# Output: platform=linux/amd64 or platform=linux/arm64

set -e

LAMBDA_PATH="${1}"
OUTPUT_FILE="${2:-$GITHUB_OUTPUT}"

if [ -z "$LAMBDA_PATH" ]; then
  echo "Usage: determine-docker-platform.sh <lambda_path> [output_file]"
  exit 1
fi

CONFIG_FILE="${LAMBDA_PATH}/lambda-config.yaml"

if [ -f "$CONFIG_FILE" ]; then
  if ! command -v yq &> /dev/null; then
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
  fi
  ARCH=$(yq eval '.lambda.architectures // "x86_64"' "$CONFIG_FILE")
else
  ARCH="x86_64"
fi

case "$ARCH" in
  x86_64) PLATFORM="linux/amd64" ;;
  arm64)  PLATFORM="linux/arm64" ;;
  *)
    echo "::error::Unsupported architecture: $ARCH. Use x86_64 or arm64"
    exit 1
    ;;
esac

echo "platform=$PLATFORM" >> "$OUTPUT_FILE"
