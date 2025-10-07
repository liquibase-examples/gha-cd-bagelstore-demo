#!/bin/bash
# Create IAM User for Harness Deployments
#
# This script creates an IAM user with the minimum required permissions for:
# - Terraform to provision AWS infrastructure
# - Harness pipeline to deploy applications
#
# Usage: ./scripts/create-harness-aws-user.sh
#
# Prerequisites:
# - AWS CLI configured with admin permissions
# - jq installed (for JSON parsing)

set -euo pipefail

# Configuration
USER_NAME="harness-bagel-store-deployer"
POLICY_NAME="HarnessBagelStoreDeploymentPolicy"

echo "=========================================="
echo "Creating IAM User for Harness Deployments"
echo "=========================================="
echo ""
echo "This script will create:"
echo "  - IAM User: ${USER_NAME}"
echo "  - Custom IAM Policy: ${POLICY_NAME}"
echo "  - Access Key for programmatic access"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Check if user already exists
if aws iam get-user --user-name "${USER_NAME}" &>/dev/null; then
    echo "⚠️  User ${USER_NAME} already exists."
    read -p "Delete and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing user..."

        # Delete access keys
        echo "  - Deleting access keys..."
        aws iam list-access-keys --user-name "${USER_NAME}" --query 'AccessKeyMetadata[].AccessKeyId' --output text | \
        while read -r key_id; do
            aws iam delete-access-key --user-name "${USER_NAME}" --access-key-id "${key_id}" || true
        done

        # Detach policies
        echo "  - Detaching policies..."
        aws iam list-attached-user-policies --user-name "${USER_NAME}" --query 'AttachedPolicies[].PolicyArn' --output text | \
        while read -r policy_arn; do
            aws iam detach-user-policy --user-name "${USER_NAME}" --policy-arn "${policy_arn}" || true
        done

        # Delete inline policies
        echo "  - Deleting inline policies..."
        aws iam list-user-policies --user-name "${USER_NAME}" --query 'PolicyNames[]' --output text | \
        while read -r policy_name; do
            aws iam delete-user-policy --user-name "${USER_NAME}" --policy-name "${policy_name}" || true
        done

        # Delete user
        aws iam delete-user --user-name "${USER_NAME}"
        echo "✅ User deleted"
    else
        echo "Aborted."
        exit 1
    fi
fi

# Create IAM policy with exact permissions needed
echo ""
echo "Creating IAM policy..."

# Get AWS account ID for policy ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create policy document
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RDSManagement",
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:DeleteDBInstance",
        "rds:DescribeDBInstances",
        "rds:ModifyDBInstance",
        "rds:CreateDBSubnetGroup",
        "rds:DeleteDBSubnetGroup",
        "rds:DescribeDBSubnetGroups",
        "rds:AddTagsToResource",
        "rds:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AppRunnerManagement",
      "Effect": "Allow",
      "Action": [
        "apprunner:CreateService",
        "apprunner:DeleteService",
        "apprunner:DescribeService",
        "apprunner:UpdateService",
        "apprunner:ListServices",
        "apprunner:CreateAutoScalingConfiguration",
        "apprunner:DeleteAutoScalingConfiguration",
        "apprunner:DescribeAutoScalingConfiguration",
        "apprunner:ListAutoScalingConfigurations",
        "apprunner:TagResource",
        "apprunner:UntagResource",
        "apprunner:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManagerManagement",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource",
        "secretsmanager:ListSecrets"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Management",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53Management",
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

# Check if policy already exists
if aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" &>/dev/null; then
    echo "⚠️  Policy ${POLICY_NAME} already exists."
    echo "   Deleting old policy..."

    # List and delete all policy versions except default
    aws iam list-policy-versions --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
        --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text | \
    while read -r version_id; do
        aws iam delete-policy-version \
            --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
            --version-id "${version_id}" || true
    done

    # Delete the policy
    aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    echo "   Old policy deleted"
fi

# Create the policy
POLICY_ARN=$(aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document "${POLICY_DOCUMENT}" \
    --description "Permissions for Harness to deploy Bagel Store application" \
    --query 'Policy.Arn' \
    --output text)

echo "✅ Policy created: ${POLICY_ARN}"

# Create IAM user
echo ""
echo "Creating IAM user..."
aws iam create-user \
    --user-name "${USER_NAME}" \
    --tags Key=Purpose,Value=HarnessDeployment Key=Project,Value=BagelStore

echo "✅ User created: ${USER_NAME}"

# Attach policy to user
echo ""
echo "Attaching policy to user..."
aws iam attach-user-policy \
    --user-name "${USER_NAME}" \
    --policy-arn "${POLICY_ARN}"

echo "✅ Policy attached"

# Create access key
echo ""
echo "Creating access key..."
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "${USER_NAME}" --output json)

ACCESS_KEY_ID=$(echo "${ACCESS_KEY_OUTPUT}" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "${ACCESS_KEY_OUTPUT}" | jq -r '.AccessKey.SecretAccessKey')

echo "✅ Access key created"

# Display results
echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Add these values to terraform/terraform.tfvars:"
echo ""
echo "aws_access_key_id = \"${ACCESS_KEY_ID}\""
echo "aws_secret_access_key = \"${SECRET_ACCESS_KEY}\""
echo ""
echo "⚠️  IMPORTANT: Save these credentials securely!"
echo "   The secret access key will not be shown again."
echo ""
echo "IAM User ARN: arn:aws:iam::${ACCOUNT_ID}:user/${USER_NAME}"
echo "IAM Policy ARN: ${POLICY_ARN}"
echo ""
echo "To delete this user later:"
echo "  aws iam delete-access-key --user-name ${USER_NAME} --access-key-id ${ACCESS_KEY_ID}"
echo "  aws iam detach-user-policy --user-name ${USER_NAME} --policy-arn ${POLICY_ARN}"
echo "  aws iam delete-user --user-name ${USER_NAME}"
echo "  aws iam delete-policy --policy-arn ${POLICY_ARN}"
echo ""
