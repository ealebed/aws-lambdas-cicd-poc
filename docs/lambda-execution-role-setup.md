# Lambda Execution Role Setup

## Overview

You need **two separate IAM roles** for Lambda deployment:

1. **GitHub Actions Role** (for CI/CD)
   - Used by GitHub Actions to deploy Lambda functions
   - Trust: `token.actions.githubusercontent.com` (OIDC)

2. **Lambda Execution Role** (for runtime)
   - Used by Lambda service to execute your function
   - Trust: `lambda.amazonaws.com`

## Create Lambda Execution Role

### Step 1: Create the Role

**Trust Policy** (allows Lambda service to assume the role):
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

### Step 2: Attach Permissions Policy

**Minimum Required Permissions** (for basic Lambda execution):
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
```

**If using X-Ray tracing**, add:
```json
{
    "Effect": "Allow",
    "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
    ],
    "Resource": "*"
}
```

**If using VPC**, add:
```json
{
    "Effect": "Allow",
    "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
    ],
    "Resource": "*"
}
```

**If accessing other AWS services** (S3, DynamoDB, SQS, etc.), add specific permissions as needed.

### Step 3: Use AWS Managed Policy (Alternative)

For development/testing, you can use AWS managed policy:
- `AWSLambdaBasicExecutionRole` - Basic CloudWatch Logs
- `AWSLambdaVPCAccessExecutionRole` - VPC access + basic logs
- `AWSLambdaXRayExecutionRole` - X-Ray tracing

**Note**: For production, follow least privilege and create custom policies with only required permissions.

## Configuration Options

### Option 1: Set in lambda-config.yaml (Recommended for per-function roles)

Add to your `lambda-config.yaml`:
```yaml
lambda:
  role_arn: "arn:aws:iam::531438381462:role/lambda-execution-role"
  # ... other config
```

### Option 2: Set as GitHub Secret (Recommended for shared role)

1. Create the role in AWS
2. Add secret in GitHub: `LAMBDA_EXECUTION_ROLE_ARN`
3. Value: `arn:aws:iam::531438381462:role/lambda-execution-role`

The workflow will automatically use this secret if `role_arn` is not set in `lambda-config.yaml`.

## Example: Complete Setup

### 1. Create Role via AWS CLI

```bash
# Create role with trust policy
aws iam create-role \
  --role-name lambda-execution-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach basic execution policy
aws iam attach-role-policy \
  --role-name lambda-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Get the role ARN
aws iam get-role --role-name lambda-execution-role --query 'Role.Arn' --output text
```

### 2. Configure in GitHub

Add secret: `LAMBDA_EXECUTION_ROLE_ARN` = `arn:aws:iam::531438381462:role/lambda-execution-role`

### 3. Verify

The workflow will use this role when deploying Lambda functions. The role ARN will be shown in the "Determine Lambda execution role ARN" step.

## Role Naming Suggestions

- `lambda-execution-role` - Single shared role for all Lambdas
- `lambda-execution-role-dev` - Environment-specific roles
- `lambda-{function-name}-execution-role` - Per-function roles

## Security Best Practices

1. **Least Privilege**: Only grant permissions the Lambda actually needs
2. **Separate Roles**: Use different roles for different functions if they need different permissions
3. **Environment-Specific**: Consider separate roles per environment (dev/test/prod)
4. **Regular Review**: Periodically review and audit role permissions
5. **No Admin Access**: Never use administrator access for Lambda execution roles

## Troubleshooting

**Error**: "The role defined for the function cannot be assumed by Lambda"
- **Cause**: Role trust policy doesn't allow `lambda.amazonaws.com`
- **Fix**: Update trust policy to include Lambda service principal

**Error**: "User is not authorized to perform: iam:PassRole"
- **Cause**: GitHub Actions role doesn't have permission to pass the Lambda execution role
- **Fix**: Add `iam:PassRole` permission to GitHub Actions role for the Lambda execution role ARN
