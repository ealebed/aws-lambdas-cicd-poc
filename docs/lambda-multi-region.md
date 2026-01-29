# Multi-region Lambda deployment

## Overview

Lambdas can be deployed to multiple AWS regions (same account). One image is built and pushed to the **primary** region’s ECR; the same image is then copied to each other region’s ECR and the function is deployed there.

## Configuration

### `lambda-config.yaml`

Use `deploy.<environment>.regions` to define target regions per environment:

```yaml
deploy:
  dev:
    regions: []   # empty = use GitHub env vars.AWS_REGION only (single region)
  test:
    regions: [eu-west-1, us-east-1]
  prod:
    regions: [eu-west-1, us-east-1]
```

- **Primary region**: First in the list, or `vars.AWS_REGION` when the list is empty.
- **DEV**: Typically `regions: []` so only the default region from GitHub env is used.
- **Other envs**: List all regions; the first is used for build/ECR push, then the image is replicated to the others.

### Manual deploy – region

On **workflow_dispatch**, the release workflow has a **region** input:

- **all** (default): Deploy to every region in `deploy.<env>.regions` (or the default region for dev).
- **eu-west-1**, **us-east-1**, …: Deploy only to that region. The workflow **validates** that the chosen region is in `deploy.<env>.regions` (or the default region for dev) and fails otherwise.

## ECR lifecycle policy

Each ECR repository gets a lifecycle policy (see `scripts/ecr-lifecycle-policy.json`):

1. **Untagged images**: Expired after 1 day.
2. **Tagged images**: Only the **most recent** tagged image is kept (`imageCountMoreThan: 1`).

So there is always at least one image in the repo, and old tags are removed. Age-based rules (e.g. “expire after 7 days”) are not used so we never risk leaving the repo empty.

## IAM

- **GitHub OIDC role**: Must be allowed to use Lambda and ECR in **every** target region (e.g. `eu-west-1` and `us-east-1`).
- **Lambda execution role**: Account-global; one role can be used by the same function in all regions.
