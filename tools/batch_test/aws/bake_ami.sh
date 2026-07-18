#!/usr/bin/env bash
# Bake the batch-runner AMI. Two phases:
#   ./bake_ami.sh start   -> launch an on-demand instance, print SSH command
#   (you SSH in, run setup_on_instance.sh, log into steamcmd once)
#   ./bake_ami.sh finish  -> create AMI from it, terminate the instance
set -euo pipefail
cd "$(dirname "$0")"
source aws.env

STATE_FILE=.bake_instance_id

case "${1:-}" in
start)
    # Ubuntu 24.04 LTS official AMI via SSM parameter (region-correct)
    BASE_AMI=$(aws ssm get-parameter --region "$AWS_REGION" \
        --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
        --query Parameter.Value --output text)
    ID=$(aws ec2 run-instances --region "$AWS_REGION" \
        --image-id "$BASE_AMI" --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" --security-group-ids "$SECURITY_GROUP" \
        --iam-instance-profile Name="$IAM_PROFILE" \
        --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":80,"VolumeType":"gp3"}}]' \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=dota2bot-ami-bake}]' \
        --query 'Instances[0].InstanceId' --output text)
    echo "$ID" > "$STATE_FILE"
    echo "waiting for instance $ID ..."
    aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$ID"
    IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo ""
    echo "SSH in and prepare it (see aws/README.md step 2):"
    echo "  ssh ubuntu@$IP"
    echo "then run: ./bake_ami.sh finish"
    ;;
finish)
    ID=$(cat "$STATE_FILE")
    AMI=$(aws ec2 create-image --region "$AWS_REGION" --instance-id "$ID" \
        --name "dota2bot-batch-$(date +%Y%m%d)" \
        --description "dota2 headless batch runner" \
        --query ImageId --output text)
    echo "creating AMI $AMI (takes ~10 min) ..."
    aws ec2 wait image-available --region "$AWS_REGION" --image-ids "$AMI"
    aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids "$ID" > /dev/null
    sed -i "s/^AMI_ID=.*/AMI_ID=$AMI/" aws.env
    rm -f "$STATE_FILE"
    echo "done: AMI_ID=$AMI written to aws.env; bake instance terminated."
    ;;
*)
    echo "usage: $0 start|finish"; exit 1 ;;
esac
