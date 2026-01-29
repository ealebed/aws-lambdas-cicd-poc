# Lambda deploy scripts

Shared scripts used by the templated deploy workflows (Python, JavaScript, Go). Keeps workflows DRY.

| Script | Purpose |
|--------|---------|
| `parse-lambda-config.sh` | Read `lambda-config.yaml`; output function config and (with env) `deploy.<env>.regions` as `regions_json`, `primary_region`. |
| `resolve-deploy-regions.sh` | Resolve deploy region list and validate manual region. Env: `REGIONS_JSON`. Outputs: `deploy_regions_json`, `primary_region`. |
| `determine-docker-platform.sh` | Map `lambda.architectures` to Docker platform (`linux/amd64` or `linux/arm64`). Output: `platform`. |
| `ecr-ensure-repo.sh` | Create ECR repo if missing and apply lifecycle policy (default: `scripts/ecr-lifecycle-policy.json`). |
| `ecr-copy-image-to-region.sh` | Output image URI for a region: use primary URI if same region, else pull from primary ECR and push to current region. Output: `uri`. |

All scripts write to `$GITHUB_OUTPUT` by default when an output file is not passed.
