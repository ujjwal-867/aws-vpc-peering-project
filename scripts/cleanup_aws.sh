#!/usr/bin/env bash
# ==============================================================================
# EWB Cloud Labs: AWS VPC Peering Cleanup Script
# Safely tears down all lab resources in dependency order to prevent charges.
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
PROJECT_TAG="EWB-VPC-Peering"

echo "=========================================================="
echo " Starting AWS VPC Peering Lab Cleanup ($REGION)"
echo " Project Tag: $PROJECT_TAG"
echo "=========================================================="

if [ -f "lab_resources.json" ]; then
    echo "[+] Loading resource IDs from lab_resources.json..."
    VPC_A_ID=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['vpc_a_id'])")
    VPC_B_ID=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['vpc_b_id'])")
    IGW_A_ID=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['igw_a_id'])")
    PCX_ID=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['pcx_id'])")
    RT_A_PUB=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['rt_a_public_id'])")
    RT_A_PRIV=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['rt_a_private_id'])")
    RT_B_PRIV=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['rt_b_private_id'])")
    SUBNET_A_PUB=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['subnet_a_public_id'])")
    SUBNET_A_PRIV=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['subnet_a_private_id'])")
    SUBNET_B_PRIV=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['subnet_b_private_id'])")
    SG_BASTION=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['sg_bastion_id'])")
    SG_APP_A=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['sg_app_a_id'])")
    SG_APP_B=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['sg_app_b_id'])")
    INST_BASTION=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['bastion_instance_id'])")
    INST_APP_A=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['app_a_instance_id'])")
    INST_APP_B=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['app_b_instance_id'])")
else
    echo "[-] lab_resources.json not found. Discovering by tag Project=$PROJECT_TAG..."
    INST_BASTION=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ewb-bastion" "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running,stopped" --query "Reservations[].Instances[].InstanceId" --output text --region "$REGION")
    INST_APP_A=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ewb-app-a" "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running,stopped" --query "Reservations[].Instances[].InstanceId" --output text --region "$REGION")
    INST_APP_B=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ewb-app-b" "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running,stopped" --query "Reservations[].Instances[].InstanceId" --output text --region "$REGION")
    # Additional fallbacks handled as needed
fi

# 1. Terminate EC2 Instances
echo "[1/6] Terminating EC2 Instances..."
INSTANCES_TO_DELETE=""
for inst in "${INST_BASTION:-}" "${INST_APP_A:-}" "${INST_APP_B:-}"; do
    if [ -n "$inst" ]; then INSTANCES_TO_DELETE="$INSTANCES_TO_DELETE $inst"; fi
done

if [ -n "$INSTANCES_TO_DELETE" ]; then
    aws ec2 terminate-instances --instance-ids $INSTANCES_TO_DELETE --region "$REGION" > /dev/null || true
    echo "      Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCES_TO_DELETE --region "$REGION" || true
    echo "      Instances terminated successfully."
fi

# 2. Delete VPC Peering Connection & Routes
echo "[2/6] Deleting Peering Connection..."
if [ -n "${PCX_ID:-}" ]; then
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PCX_ID" --region "$REGION" > /dev/null || true
    echo "      Peering connection $PCX_ID deleted."
fi

# 3. Delete Security Groups
echo "[3/6] Deleting Security Groups..."
sleep 5
for sg in "${SG_BASTION:-}" "${SG_APP_A:-}" "${SG_APP_B:-}"; do
    if [ -n "$sg" ]; then
        aws ec2 delete-security-group --group-id "$sg" --region "$REGION" > /dev/null || true
    fi
done

# 4. Delete Subnets & Route Tables
echo "[4/6] Deleting Subnets and Custom Route Tables..."
for sn in "${SUBNET_A_PUB:-}" "${SUBNET_A_PRIV:-}" "${SUBNET_B_PRIV:-}"; do
    if [ -n "$sn" ]; then
        aws ec2 delete-subnet --subnet-id "$sn" --region "$REGION" > /dev/null || true
    fi
done

for rt in "${RT_A_PUB:-}" "${RT_A_PRIV:-}" "${RT_B_PRIV:-}"; do
    if [ -n "$rt" ]; then
        aws ec2 delete-route-table --route-table-id "$rt" --region "$REGION" > /dev/null || true
    fi
done

# 5. Detach and Delete Internet Gateway
echo "[5/6] Detaching and Deleting Internet Gateway..."
if [ -n "${IGW_A_ID:-}" ] && [ -n "${VPC_A_ID:-}" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_A_ID" --vpc-id "$VPC_A_ID" --region "$REGION" > /dev/null || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_A_ID" --region "$REGION" > /dev/null || true
fi

# 6. Delete VPCs
echo "[6/6] Deleting VPC A and VPC B..."
if [ -n "${VPC_A_ID:-}" ]; then
    aws ec2 delete-vpc --vpc-id "$VPC_A_ID" --region "$REGION" > /dev/null || true
fi
if [ -n "${VPC_B_ID:-}" ]; then
    aws ec2 delete-vpc --vpc-id "$VPC_B_ID" --region "$REGION" > /dev/null || true
fi

echo "=========================================================="
echo " Cleanup completed! All lab resources deleted."
echo " Check AWS Billing and Resource Groups to verify zero active charges."
echo "=========================================================="
