# aws-lambdas-cicd-poc


This repository contains a complete CI/CD workflow for building and deploying AWS Lambda functions written in Python, JavaScript, and Go using GitHub Actions. Deployments use the official `aws-actions/aws-lambda-deploy` action for container-image Lambdas, driven by per-function `lambda-config.yaml` values.

## Repository Structure

```
aws-lambdas-cicd-poc/
├── .github/
│   └── workflows/
│       ├── wfl_pr_validation.yml      # CI: PR validation workflow
│       ├── wfl_lambdas_release.yml     # CD: Release workflow (auto DEV, manual TEST/PROD)
│       ├── tpl_python_validation.yml   # Reusable: Python validation
│       ├── tpl_lambda_deploy.yml       # Reusable: Lambda deployment (python/javascript/go)
│       ├── tpl_javascript_validation.yml # Reusable: JavaScript validation
│       └── tpl_go_validation.yml       # Reusable: Go validation
├── lambdas/
│   ├── python/
│   │   ├── Dockerfile             # Shared Python Dockerfile
│   │   ├── pyproject.toml          # Shared Python linter config
│   │   ├── python_1_example/
│   │   │   ├── lambda_function.py
│   │   │   ├── requirements.txt
│   │   │   ├── test_lambda_function.py
│   │   │   └── lambda-config.yaml  # Lambda-specific configuration
│   │   └── python_2_example/
│   │       ├── lambda_function.py
│   │       ├── requirements.txt
│   │       ├── test_lambda_function.py
│   │       └── lambda-config.yaml
│   ├── javascript/
│   │   ├── Dockerfile             # Shared JavaScript Dockerfile
│   │   ├── .eslintrc.json         # Shared ESLint config
│   │   ├── .prettierrc.json       # Shared Prettier config
│   │   ├── javascript_1_example/
│   │   │   ├── index.js
│   │   │   ├── package.json
│   │   │   ├── index.test.js
│   │   │   └── lambda-config.yaml
│   │   └── javascript_2_example/
│   │       ├── index.js
│   │       ├── package.json
│   │       ├── index.test.js
│   │       └── lambda-config.yaml
│   └── go/
│       ├── Dockerfile             # Shared Go Dockerfile
│       ├── .golangci.yaml          # Shared golangci-lint config
│       ├── go_1_example/
│       │   ├── main.go
│       │   ├── main_test.go
│       │   ├── go.mod
│       │   └── lambda-config.yaml
│       └── go_2_example/
│           ├── main.go
│           ├── main_test.go
│           ├── go.mod
│           └── lambda-config.yaml
├── scripts/
│   └── parse-lambda-config.sh     # Script to parse lambda-config.yaml
├── .pre-commit-config.yaml         # Pre-commit hooks configuration
└── README.md
```

## Key Features

- **Multi-language support**: Python 3.13, Node.js 24, Go 1.25
- **Container-based deployment**: Uses official AWS Lambda base images from ECR Public
- **Automatic validation**: PR validation with format, lint, and test checks
- **Automatic DEV deployment**: Deploys to DEV environment on merge to master
- **Manual TEST/PROD deployment**: Workflow dispatch for controlled deployments
- **Nested folder structure**: Support for multiple Lambdas per language (lambda_name = folder_name)
- **IAM Role-based authentication**: No static credentials, uses OIDC
- **Separate IAM roles**: GitHub Actions role for CI/CD, Lambda execution role for runtime
- **Reusable workflow templates**: Templates can be moved to shared repositories
- **Workflow timeouts**: Workflows have a 15-minute timeout to prevent hanging jobs
- **Simplified configuration**: Uses environment variables (vars) for non-sensitive config
- **Shared Dockerfiles**: One Dockerfile per language, shared across all lambdas of that language
- **Centralized parsing**: Lambda configuration parsing handled by reusable script
- **Automatic ECR repository naming**: Repositories created as `lambda-{function-name}`
- **Official deploy action**: Uses `aws-actions/aws-lambda-deploy` for container-image Lambdas, sourcing memory/timeout/storage/env/tags from each `lambda-config.yaml` plus dynamic tags (Environment, Region, Version, Language, Team, Service)
- **Smart image tagging**: Timestamp-based tags with SNAPSHOT suffix for non-master branches

## Lambda Runtime Versions

- **Python**: 3.13 (using `public.ecr.aws/lambda/python:3.13`)
- **Node.js**: 24.x (using `public.ecr.aws/lambda/nodejs:24`)
- **Go**: 1.25.0 (using `public.ecr.aws/lambda/provided:al2023`)

## Workflows

### 1. PR Validation (`wfl_pr_validation.yml`)

**Trigger**: Pull requests to `master` branch

**What it does**:
- Detects changed Lambda functions by language
- Runs validation for each changed Lambda:
  - **Python**: Black formatting, Ruff linting, pytest tests
  - **JavaScript**: Prettier formatting, ESLint linting, Jest tests
  - **Go**: gofmt, go vet, golangci-lint, go tests with race detector

**Path-based triggering**: Only runs validation for Lambdas with changes in their directory.

### 2. Release Deployment (`wfl_lambdas_release.yml`)

**Triggers**:
- **Automatic**: Push to `master` branch → deploys to `dev` environment
- **Manual**: Workflow dispatch → deploys to selected environment (`dev`, `test`, or `prod`)

**What it does**:
- **Automatic mode** (push to master):
  - Detects changed Lambda functions
  - Generates image tags: timestamp format (e.g., `2026.01.15-14.30`) for master branch
  - Builds Docker images using Docker Buildx and official AWS Lambda base images
  - Pushes images to AWS ECR with caching (repository auto-created as `lambda-{function-name}`)
  - Deploys/updates Lambda functions in DEV environment
  - Creates new Lambda functions if they don't exist

- **Manual mode** (workflow_dispatch):
  - Allows deployment to any environment (dev/test/prod)
  - Options:
    - **Environment**: `dev`, `test`, or `prod`
    - **Language**: `all`, `python`, `javascript`, or `go`
    - **Lambda name**: Specific Lambda name (required if language is not "all")

**Environments**: `dev` (automatic), `test`/`prod` (manual)

**Image Tagging Strategy**:
- **Master branch**: `YYYY.MM.DD-HH.MM` (e.g., `2026.01.15-14.30`)
- **Other branches**: `YYYY.MM.DD-HH.MM-SNAPSHOT` (e.g., `2026.01.15-14.30-SNAPSHOT`)
- Images are also tagged with: `latest`

**ECR Repository Naming**:
- Automatically generated as `lambda-{function-name}`
- Example: For function `python_1_example`, repository is `lambda-python_1_example`

## Reusable Workflows

All reusable workflows use `workflow_call` and can be called from other workflows or moved to shared repositories.

### Validation Workflows (Templates)

- `tpl_python_validation.yml`: Format, lint, and test Python Lambdas
- `tpl_javascript_validation.yml`: Format, lint, and test JavaScript Lambdas
- `tpl_go_validation.yml`: Format, lint, and test Go Lambdas

### Deployment Workflows (Templates)

- `tpl_lambda_deploy.yml`: Build and deploy Lambda containers (Python, JavaScript, or Go; language passed as input)

**Note**: The main workflows (`wfl_pr_validation.yml`, `wfl_lambdas_release.yml`) call these reusable workflow templates using `uses:` instead of duplicating logic.

## GitHub Environment Configuration

GitHub Environments allow you to configure different deployment targets (dev, test, prod) with environment-specific secrets and protection rules. Each environment corresponds to a different AWS account.

### Creating GitHub Environments

1. **Navigate to Environment Settings**:
   - Go to your GitHub repository
   - Click on **Settings** (in the repository navigation bar)
   - In the left sidebar, click **Environments**

2. **Create New Environment**:
   - Click **New environment** button
   - Enter the environment name (e.g., `dev`, `test`, `prod`)
   - Click **Configure environment**

3. **Repeat for Each Environment**:
   - Create three environments: `dev`, `test`, and `prod`
   - Each environment will have its own configuration and secrets

### Configuring Environment Variables and Secrets

For each environment (`dev`, `test`, `prod`), you need to configure:

#### Environment Variables (Vars)

Environment variables are non-sensitive values that can be used in workflows. They're perfect for configuration values like AWS region and account ID.

1. **Navigate to Environment Variables**:
   - In the environment configuration page, scroll to **Environment variables** section
   - Click **Add variable** for each variable below

2. **Required Environment Variables**:

   | Variable Name | Description | Example Value |
   |--------------|-------------|---------------|
   | `AWS_REGION` | AWS region for deployment | `us-east-1` |
   | `AWS_ACCOUNT_ID` | AWS account ID | `123456789012` |

3. **Adding Environment Variables**:
   - Click **Add variable**
   - Enter the variable name (exactly as shown in the table above)
   - Enter the variable value
   - Click **Add variable**
   - Repeat for both variables

#### Environment Secrets

Secrets are used for sensitive values like IAM role ARNs.

1. **Navigate to Environment Secrets**:
   - In the environment configuration page, scroll to **Environment secrets** section
   - Click **Add secret**

2. **Required Secrets**:

   | Secret Name | Description | Example Value |
   |------------|-------------|---------------|
   | `AWS_ROLE_ARN` | ARN of the IAM role for GitHub Actions OIDC authentication (used for CI/CD deployment). | `arn:aws:iam::123456789012:role/github-actions-role` |
   | `LAMBDA_EXECUTION_ROLE_ARN` | ARN of the IAM role for Lambda function execution (used at runtime). Optional - can also be set in `lambda-config.yaml`. | `arn:aws:iam::123456789012:role/lambda-execution-role` |

3. **Adding Secrets**:
   - Click **Add secret** for each secret
   - Enter the secret name exactly as shown
   - Enter the IAM role ARN
   - Click **Add secret**
   - Repeat for both secrets

**Notes**:
- `AWS_ROLE_ARN` is used by GitHub Actions to authenticate and deploy resources (ECR, Lambda, etc.)
- `LAMBDA_EXECUTION_ROLE_ARN` is the role that Lambda service assumes to execute your function
- If `LAMBDA_EXECUTION_ROLE_ARN` is not set as a secret, you can specify it in `lambda-config.yaml` with `role_arn`
- Priority: `lambda-config.yaml` → `LAMBDA_EXECUTION_ROLE_ARN` secret → `AWS_ROLE_ARN` secret (fallback)
- `AWS_ROLE_SESSION_NAME` is automatically generated as `GitHubActionsSession-{environment}-{lambda_name}` (e.g., `GitHubActionsSession-dev-python_1_example`)
- `ECR_REPOSITORY` is automatically generated as `lambda-{function-name}` (e.g., `lambda-python_1_example`)
- The same `AWS_ROLE_ARN` is used for both AWS authentication and Lambda execution role

4. **Environment-Specific Values**:
   - Each environment should have values pointing to its respective AWS account
   - For example:
     - `dev` environment → AWS Account DEV (e.g., `123456789012`)
     - `test` environment → AWS Account TEST (e.g., `234567890123`)
     - `prod` environment → AWS Account PROD (e.g., `345678901234`)

### Environment Protection Rules (Optional but Recommended)

For `test` and `prod` environments, consider adding protection rules:

1. **Required Reviewers** (Recommended for prod):
   - In the environment configuration, scroll to **Deployment branches**
   - Enable **Required reviewers**
   - Add team members or individuals who must approve deployments
   - This ensures manual approval before production deployments

2. **Wait Timer** (Optional):
   - Enable **Wait timer**
   - Set a delay (e.g., 5 minutes) before deployment starts
   - Useful for giving time to cancel if needed

3. **Deployment Branches**:
   - Configure which branches can deploy to this environment
   - For `dev`: Allow `master` branch (automatic deployments)
   - For `test`/`prod`: Restrict to specific branches or allow all (manual deployments)

### Environment Configuration Summary

After setup, each environment should have:

- **Environment Name**: `dev`, `test`, or `prod`
- **2 Environment Variables**: `AWS_REGION`, `AWS_ACCOUNT_ID`
- **2 Secrets**: `AWS_ROLE_ARN`, `LAMBDA_EXECUTION_ROLE_ARN` (or set `role_arn` in `lambda-config.yaml`)
- **Automatic Values**:
  - Session Name: `GitHubActionsSession-{environment}-{lambda_name}` (e.g., `GitHubActionsSession-dev-python_1_example`)
  - ECR Repository: `lambda-{function-name}` (e.g., `lambda-python_1_example`)
- **Protection Rules** (optional): Reviewers and wait timers for test/prod

### Configuring Environment Variables (Repository Level - Optional for Testing)

For testing purposes, you can also configure environment variables at the repository level instead of environment-specific:

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Click **Variables** tab
3. Add repository-level variables:
   - `AWS_REGION`: AWS region (e.g., `us-east-1`)
   - `AWS_ACCOUNT_ID`: AWS account ID (e.g., `123456789012`)

**Note**: Repository-level variables are accessible to all workflows but are less secure than environment-specific variables. For production, use environment-specific variables.

### Verifying Environment Configuration

To verify your environments are configured correctly:

1. Go to **Settings** → **Environments**
2. Click on each environment (`dev`, `test`, `prod`)
3. Verify:
   - **Environment Variables**: `AWS_REGION` and `AWS_ACCOUNT_ID` are present
   - **Secrets**: `AWS_ROLE_ARN` is present
4. Check that protection rules are configured as desired

### Troubleshooting Environment Issues

**Issue**: Workflow fails with "Environment not found"
- **Solution**: Ensure the environment name in the workflow matches exactly (case-sensitive)

**Issue**: Workflow fails with "Secret not found" or "Variable not found"
- **Solution**:
  - Verify `AWS_ROLE_ARN` and `LAMBDA_EXECUTION_ROLE_ARN` secrets are added to the environment (or set `role_arn` in `lambda-config.yaml`)
  - Verify `AWS_REGION` and `AWS_ACCOUNT_ID` variables are added to the environment
  - Check that variable/secret names match exactly (case-sensitive)

**Issue**: Deployment fails with AWS authentication error
- **Solution**: Check that `AWS_ROLE_ARN` is correct and the IAM role trust policy allows GitHub Actions

**Issue**: Lambda deployment fails with "The role defined for the function cannot be assumed by Lambda"
- **Solution**:
  - Ensure you have a separate Lambda execution role (not the GitHub Actions role)
  - Set `LAMBDA_EXECUTION_ROLE_ARN` secret or add `role_arn` to `lambda-config.yaml`
  - Verify the Lambda execution role trust policy allows `lambda.amazonaws.com` to assume it
  - Ensure the GitHub Actions role has `iam:PassRole` permission for the Lambda execution role

**Issue**: Docker image build fails with "image manifest media type not supported"
- **Solution**: This is automatically handled by the workflow (provenance and SBOM are disabled), but ensure you're using the latest workflow templates

**Issue**: Cannot deploy to prod (blocked by protection rules)
- **Solution**: Ensure required reviewers have approved the deployment, or adjust protection rules

## AWS IAM Role Setup

You need **two separate IAM roles** for Lambda deployment:

1. **GitHub Actions Role** (for CI/CD deployment)
   - Used by GitHub Actions to authenticate and deploy resources
   - Trust: GitHub OIDC (`token.actions.githubusercontent.com`)
   - Permissions: ECR, Lambda management, IAM PassRole

2. **Lambda Execution Role** (for Lambda runtime)
   - Used by Lambda service to execute your function
   - Trust: `lambda.amazonaws.com`
   - Permissions: CloudWatch Logs, and any other services your Lambda needs

See [docs/lambda-execution-role-setup.md](docs/lambda-execution-role-setup.md) for detailed setup instructions.

### GitHub Actions Role Setup

#### GitHub OIDC Provider

1. Create an OIDC identity provider in AWS IAM:
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. Create an IAM role with trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"
        }
      }
    }
  ]
}
```

#### Required IAM Permissions for GitHub Actions (Deploy) Role

The deploy role (GitHub Actions OIDC role) needs the following permissions. For **multi-region** deploy, this role must have these permissions in **every target region** (ECR and Lambda are regional).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:CreateRepository",
        "ecr:DeleteRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:SetRepositoryPolicy",
        "ecr:UploadLayerPart",
        "ecr:PutLifecyclePolicy"
      ],
      "Resource": ["*"]
    },
    {
      "Sid": "LambdaDeploy",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:ListTags",
        "lambda:PublishVersion",
        "lambda:TagResource",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration"
      ],
      "Resource": ["arn:aws:lambda:*:*:function:*"]
    },
    {
      "Sid": "PassRolesDefinition",
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": ["arn:aws:iam::<ACCOUNT_ID>:role/lambda-execution-role"]
    }
  ]
}
```

**Important Notes**:
- Replace `<ACCOUNT_ID>` with your AWS account ID.
- ECR: create repo, push images, and apply lifecycle policy (`ecr:PutLifecyclePolicy`).
- Lambda: create/update function, publish version, and update tags (`lambda:TagResource`, `lambda:GetFunctionConfiguration`).
- The role must be able to pass the Lambda execution role to Lambda (`iam:PassRole`).

### Lambda Execution Role Setup

The Lambda execution role is used by Lambda service to execute your function. See [docs/lambda-execution-role-setup.md](docs/lambda-execution-role-setup.md) for complete setup instructions.

**Quick Setup**:

1. **Trust Policy** (allows Lambda service to assume the role):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

2. **Minimum Permissions** (for container-image Lambdas):

   - **ECR image retrieval** (Lambda pulls the image from ECR at runtime):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaECRImageRetrievalPolicy",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": ["*"]
    }
  ]
}
```

   - **CloudWatch Logs** (recommended): Attach the AWS managed policy **`AWSLambdaBasicExecutionRole`**, or use an inline policy with `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` on `arn:aws:logs:*:*:*`.

3. **Configuration**:
   - Set `LAMBDA_EXECUTION_ROLE_ARN` secret in GitHub environment, OR
   - Add `role_arn` to `lambda-config.yaml` in your Lambda function directory

## Pre-commit Hooks Setup

Pre-commit hooks are configured to run checks before commits:

1. **Install pre-commit**:
   ```bash
   pip install pre-commit
   # or
   brew install pre-commit
   ```

2. **Install hooks**:
   ```bash
   pre-commit install
   ```

3. **Run on all files** (optional):
   ```bash
   pre-commit run --all-files
   ```

### Pre-commit Hooks Included

- **General**: trailing whitespace, end-of-file fixer, YAML/JSON/TOML validation, large files, merge conflicts, private key detection
- **Python**: Black formatting, Ruff linting
- **JavaScript**: Prettier formatting, ESLint linting
- **Go**: gofmt, go vet, go mod tidy, go unit tests (with race detector), golangci-lint

**Note**: Pre-commit hooks run the same formatters and linters as CI validation workflows, ensuring consistency between local development and CI/CD pipelines. Pre-commit hooks can auto-fix issues, while CI only checks and fails if fixes are needed.

## Lambda Configuration (lambda-config.yaml)

Each Lambda function can have a `lambda-config.yaml` file in its directory to configure all aspects of the Lambda function. This configuration is used by the CI/CD workflows to deploy the function using the official `aws-actions/aws-lambda-deploy` action.

**Configuration Parsing**: The `lambda-config.yaml` file is parsed by the `scripts/parse-lambda-config.sh` script, which extracts all configuration values and outputs them as GitHub Actions step outputs. This centralized approach ensures consistency across all language workflows.

### Configuration File Structure

The configuration file uses a flat structure (not nested) for easier readability and maintenance:

```yaml
# Lambda Configuration
# This file defines the configuration for this Lambda function
# Used by CI/CD workflows for deployment
# All values are optional and have defaults if not specified

lambda:
  # Function name (defaults to folder name if not specified)
  name: my-lambda

  # Function description
  description: "My Lambda function description"

  # Runtime configuration
  memory_size: 256  # MB (128-10240, must be multiple of 64)
  timeout: 30       # seconds (1-900)
  ephemeral_storage: 512  # MB (512-10240)
  architectures: x86_64  # x86_64 or arm64

  # Lambda execution role ARN (optional: set here or in GitHub environment as LAMBDA_EXECUTION_ROLE_ARN secret)
  # Priority: lambda-config.yaml role_arn > LAMBDA_EXECUTION_ROLE_ARN secret > AWS_ROLE_ARN secret (fallback)
  # role_arn: "arn:aws:iam::123456789012:role/lambda-execution-role"

  # Environment variables
  environment:
    variables:
      GREETING: "Hello from Lambda!"
      LOG_LEVEL: "INFO"

  # VPC configuration (optional)
  # vpc_config:
  #   subnet_ids:
  #     - "subnet-12345678"
  #     - "subnet-87654321"
  #   security_group_ids:
  #     - "sg-12345678"

  # Dead letter queue configuration (optional)
  # dead_letter_config:
  #   target_arn: "arn:aws:sqs:region:account:dlq-name"

  # KMS key ARN for encryption (optional)
  # kms_key_arn: "arn:aws:kms:region:account:key/key-id"

  # X-Ray tracing configuration (optional)
  # tracing_config:
  #   mode: "Active"  # PassThrough or Active

  # Lambda layers (ARNs) - only for ZIP packages, not container images
  # layers:
  #   - "arn:aws:lambda:region:account:layer:layer-name:version"

  # EFS file system configuration (optional)
  # file_system_configs:
  #   - arn: "arn:aws:elasticfilesystem:region:account:file-system/fs-id"
  #     local_mount_path: "/mnt/efs"

  # Container image configuration (optional)
  # image_config:
  #   command:
  #     - "app.handler"
  #   entry_point:
  #     - "/lambda-entrypoint.sh"
  #   working_directory: "/var/task"

  # SnapStart configuration (optional, Java only)
  # snap_start:
  #   apply_on: "PublishedVersions"  # None or PublishedVersions

  # CloudWatch Logs configuration (optional)
  # logging_config:
  #   log_format: "JSON"  # JSON or Text
  #   log_group: "/aws/lambda/function-name"
  #   application_log_level: "INFO"  # TRACE, DEBUG, INFO, WARN, ERROR, FATAL
  #   system_log_level: "INFO"  # DEBUG, INFO, WARN

  # Code signing configuration ARN (optional)
  # code_signing_config_arn: "arn:aws:lambda:region:account:code-signing-config:config-id"

  # Publish new version after update (default: true)
  publish: true

  # Tags (will be merged with dynamic tags: Environment, Region, Version, Language, Service)
  # Dynamic tags are automatically added by CI/CD:
  # - Environment: from deployment environment (dev/test/prod)
  # - Region: from AWS_REGION variable
  # - Version: from image tag (timestamp)
  # - Language: python/javascript/go
  # - Service: function name
  # Your custom tags will be merged with these, with your tags taking precedence
  tags:
    Team: "platform"
    Project: "my-project"
```

### Configuration Options

**Basic Configuration:**
- `name`: Function name (optional, defaults to folder name)
- `description`: Function description
- `memory_size`: Memory allocation in MB (128-10240, must be multiple of 64)
- `timeout`: Function timeout in seconds (1-900)
- `ephemeral_storage`: Size of `/tmp` directory in MB (512-10240)
- `architectures`: Instruction set architecture (`x86_64` or `arm64`)
- `role_arn`: Lambda execution role ARN (optional - can also be set via `LAMBDA_EXECUTION_ROLE_ARN` secret)
- `publish`: Whether to publish a new version after update (default: `true`)

**Environment Variables:**
- `environment.variables`: Key-value pairs of environment variables

**Advanced Configuration (optional):**
- `vpc_config`: VPC configuration with subnet and security group IDs
- `dead_letter_config`: Dead letter queue or topic ARN for failed invocations
- `kms_key_arn`: KMS key ARN for encryption
- `tracing_config`: X-Ray tracing configuration (`PassThrough` or `Active`)
- `file_system_configs`: Amazon EFS file system configurations
- `image_config`: Container image configuration (command, entry point, working directory)
- `snap_start`: SnapStart configuration for Java functions
- `logging_config`: CloudWatch Logs configuration (log format, log group, log levels)
- `code_signing_config_arn`: Code signing configuration ARN

**Tags:**
- `tags`: Custom tags to apply to the function
- Dynamic tags are automatically added: `Environment`, `Region`, `Version`, `Language`, `Service`
- Custom tags are merged with dynamic tags, with custom tags taking precedence

### Default Values

If `lambda-config.yaml` is not present, the following defaults are used:
- Memory: 256 MB
- Timeout: 30 seconds
- Ephemeral storage: 512 MB
- Architectures: `x86_64`
- Publish: `true`
- No environment variables
- No custom tags (only dynamic tags are applied)

## Creating a New Lambda Function

### Python Lambda

1. Create directory: `lambdas/python/<lambda-name>/`
2. Add files:
   - `lambda_function.py`: Lambda handler
   - `requirements.txt`: Python dependencies
   - `test_lambda_function.py`: Tests
   - `lambda-config.yaml`: Lambda configuration (optional)

3. Example structure:
   ```
   lambdas/python/my-lambda/
   ├── lambda_function.py
   ├── requirements.txt
   ├── test_lambda_function.py
   └── lambda-config.yaml
   ```

**Note**:
- Python linter configuration (`pyproject.toml`) is shared in `lambdas/python/` and used by all Python Lambdas
- Dockerfile is shared at `lambdas/python/Dockerfile` - you don't need to create one in your lambda directory

### JavaScript Lambda

1. Create directory: `lambdas/javascript/<lambda-name>/`
2. Add files:
   - `index.js`: Lambda handler
   - `package.json`: Node.js dependencies and scripts
   - `index.test.js`: Tests
   - `lambda-config.yaml`: Lambda configuration (optional)

3. Example structure:
   ```
   lambdas/javascript/my-lambda/
   ├── index.js
   ├── package.json
   ├── index.test.js
   └── lambda-config.yaml
   ```

**Note**:
- JavaScript linter configurations (`.eslintrc.json`, `.prettierrc.json`) are shared in `lambdas/javascript/` and used by all JavaScript Lambdas
- Dockerfile is shared at `lambdas/javascript/Dockerfile` - you don't need to create one in your lambda directory

### Go Lambda

1. Create directory: `lambdas/go/<lambda-name>/`
2. Add files:
   - `main.go`: Lambda handler
   - `go.mod`: Go module definition
   - `main_test.go`: Tests
   - `lambda-config.yaml`: Lambda configuration (optional)

3. Example structure:
   ```
   lambdas/go/my-lambda/
   ├── main.go
   ├── main_test.go
   ├── go.mod
   └── lambda-config.yaml
   ```

**Note**:
- Go linter configuration (`.golangci.yaml`) is shared in `lambdas/go/` and used by all Go Lambdas
- Dockerfile is shared at `lambdas/go/Dockerfile` - you don't need to create one in your lambda directory

**Important**: The folder name (`<lambda-name>`) will be used as the Lambda function name in AWS, unless overridden in `lambda-config.yaml`.

## Dockerfile Requirements

**Shared Dockerfiles**: Each language has a single shared Dockerfile located in `lambdas/<language>/Dockerfile`. All lambdas of the same language use the same Dockerfile, ensuring consistency and easier maintenance.

All Dockerfiles use official AWS Lambda base images:

- **Python**: `lambdas/python/Dockerfile` - Uses `public.ecr.aws/lambda/python:3.13`
- **JavaScript**: `lambdas/javascript/Dockerfile` - Uses `public.ecr.aws/lambda/nodejs:24`
- **Go**: `lambdas/go/Dockerfile` - Uses `public.ecr.aws/lambda/provided:al2023` (runtime) and `golang:1.25-alpine` (build stage)

**Important**:
- Docker images are built with `provenance: false` and `sbom: false` to ensure compatibility with AWS Lambda, which doesn't support multi-architecture manifest lists
- The build context is set to the individual lambda directory, but the Dockerfile path points to the shared file
- Individual lambda directories do not need their own Dockerfiles (though they may exist for reference)

## Manual Deployment

To manually deploy a Lambda to any environment:

1. Go to **Actions** → **Lambdas Release** (workflow: `wfl_lambdas_release.yml`)
2. Click **Run workflow**
3. Select:
   - **Environment**: `dev`, `test`, or `prod`
   - **Language**: `all` (deploy all changed), `python`, `javascript`, or `go`
   - **Lambda name**: The folder name (required if language is not "all", e.g., `python_1_example`)
4. Click **Run workflow**

**Note**: When language is set to `all`, all Lambdas of changed languages will be deployed. When a specific language is selected, you must provide the Lambda name.

## Moving Reusable Workflows to Shared Repository

The reusable workflows are designed to be moved to a shared repository:

1. Move reusable workflow templates (files with `tpl_` prefix) to the shared repository's `.github/workflows/` directory
2. Update workflow calls in main workflows to use the shared repository:
   ```yaml
   uses: <org>/<shared-repo>/.github/workflows/tpl_python_validation.yml@main
   ```
3. Ensure the shared repository is accessible to this repository
4. Update all `uses:` references in `wfl_pr_validation.yml` and `wfl_lambdas_release.yml`

## Troubleshooting

### Lambda function not found during deployment

- Verify the Lambda name matches the folder name exactly
- Check that the folder exists in the correct language directory
- Ensure the Lambda function exists in AWS (or the workflow will create it)

### ECR push failures

- Verify the IAM role has ECR permissions
- Check that the ECR repository exists
- Ensure the repository name follows the pattern `lambda-{function-name}`

### OIDC authentication failures

- Verify the OIDC provider is configured correctly
- Check the trust policy allows the repository
- Ensure the role ARN in secrets is correct

### Pre-commit hooks failing

- Run `pre-commit run --all-files` to see all issues
- Fix formatting/linting issues locally
- Ensure all required tools are installed (black, ruff, prettier, eslint, golangci-lint, etc.)

## Example Lambda Functions

Example Lambda functions are provided in:
- `lambdas/python/python_1_example/`
- `lambdas/javascript/javascript_1_example/`
- `lambdas/go/go_1_example/`

These examples demonstrate:
- Basic Lambda handler structure
- Logging
- Environment variable usage
- Test structure
- `lambda-config.yaml` configuration

**Note**: Dockerfiles are shared at the language level (`lambdas/<language>/Dockerfile`), so individual lambda directories don't need their own Dockerfiles.

## Additional Notes

- All workflows use the latest stable versions of languages as of January 2026
- Docker images are built for single architecture (no multi-arch manifests) for Lambda compatibility
- Lambda execution role can be configured per-function in `lambda-config.yaml` or globally via GitHub secret
- **Shared Dockerfiles**: One Dockerfile per language ensures consistency and easier maintenance
- **Centralized Scripts**: Lambda configuration parsing is handled by `scripts/parse-lambda-config.sh`, reducing code duplication across workflows
- Container images are tagged with timestamp-based tags and `latest`
- Lambda functions are created if they don't exist, or updated if they do
- Default Lambda configuration: 256MB memory, 30s timeout (configurable in templates)
- Workflows support multiple Lambdas per language through nested folder structure
- Lambda function name = folder name (enforced for consistency)
