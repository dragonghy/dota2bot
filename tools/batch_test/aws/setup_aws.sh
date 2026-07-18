#!/usr/bin/env bash
# One-time AWS account setup for batch testing. Creates: S3 results bucket,
# IAM role (instance profile, write access to that bucket only), security
# group (SSH in), and a $20/month budget alert. Writes IDs to aws.env.
set -euo pipefail
cd "$(dirname "$0")"

REGION=${AWS_REGION:-us-west-2}
SUFFIX=$(aws sts get-caller-identity --query Account --output text | tail -c 5)
BUCKET="dota2bot-batch-results-${SUFFIX}"
ROLE="dota2bot-batch-runner"
SG_NAME="dota2bot-batch-sg"
BUDGET_LIMIT=${BUDGET_LIMIT:-20}

echo "== S3 bucket =="
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || true

echo "== IAM role + instance profile =="
cat > /tmp/trust.json <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name "$ROLE" --assume-role-policy-document file:///tmp/trust.json 2>/dev/null || true
cat > /tmp/policy.json <<EOF
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["s3:PutObject","s3:GetObject","s3:ListBucket"],
  "Resource":["arn:aws:s3:::${BUCKET}","arn:aws:s3:::${BUCKET}/*"]}]}
EOF
aws iam put-role-policy --role-name "$ROLE" --policy-name s3-results --policy-document file:///tmp/policy.json
aws iam create-instance-profile --instance-profile-name "$ROLE" 2>/dev/null || true
aws iam add-role-to-instance-profile --instance-profile-name "$ROLE" --role-name "$ROLE" 2>/dev/null || true

echo "== security group (SSH only) =="
VPC=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SG=$(aws ec2 create-security-group --region "$REGION" --group-name "$SG_NAME" \
    --description "dota2bot batch testing" --vpc-id "$VPC" --query GroupId --output text 2>/dev/null) || \
SG=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=group-name,Values="$SG_NAME" \
    --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null || true

echo "== budget alert (\$${BUDGET_LIMIT}/month, email at 80%) =="
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
EMAIL=$(aws account get-contact-information --query 'ContactInformation.WebsiteUrl' --output text 2>/dev/null || echo "")
read -r -p "Alert email address: " EMAIL
cat > /tmp/budget.json <<EOF
{"BudgetName":"dota2bot-batch","BudgetLimit":{"Amount":"${BUDGET_LIMIT}","Unit":"USD"},
 "TimeUnit":"MONTHLY","BudgetType":"COST"}
EOF
cat > /tmp/notif.json <<EOF
[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80},
  "Subscribers":[{"SubscriptionType":"EMAIL","Address":"${EMAIL}"}]}]
EOF
aws budgets create-budget --account-id "$ACCOUNT" --budget file:///tmp/budget.json \
    --notifications-with-subscribers file:///tmp/notif.json 2>/dev/null || echo "(budget exists, skipped)"

cat > aws.env <<EOF
AWS_REGION=$REGION
S3_BUCKET=$BUCKET
IAM_PROFILE=$ROLE
SECURITY_GROUP=$SG
INSTANCE_TYPE=c6i.4xlarge
AMI_ID=            # filled by bake_ami.sh finish
KEY_NAME=          # your EC2 keypair name (create one in the console if needed)
EOF
echo "wrote aws.env — fill in KEY_NAME, then run ./bake_ami.sh start"
