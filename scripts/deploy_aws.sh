#!/usr/bin/env bash
# ==============================================================================
# EWB Cloud Labs: AWS VPC Peering Deployment Script
# Automatically provisions VPC A, VPC B, Subnets, Routing, SGs, EC2 & Peering
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
STUDENT_NAME="${STUDENT_NAME:-YourName}"
KEY_NAME="ewb-lab"
KEY_PATH="$HOME/.ssh/${KEY_NAME}.pem"

echo "=========================================================="
echo " Starting AWS VPC Peering Lab Deployment ($REGION)"
echo " Student: $STUDENT_NAME | Project: EWB-VPC-Peering"
echo "=========================================================="

# 0. Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "[-] AWS CLI is not installed. Please install it or use CloudFormation."
    exit 1
fi

# Detect Public IP for Bastion Inbound
MY_IP=$(curl -s -4 https://checkip.amazonaws.com 2>/dev/null || echo "0.0.0.0")
MY_CIDR="${MY_IP}/32"
echo "[+] Detected admin client IP: $MY_CIDR"

# 1. EC2 Key Pair Setup
mkdir -p "$HOME/.ssh"
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &>/dev/null; then
    echo "[+] Creating EC2 Key Pair '$KEY_NAME'..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text --region "$REGION" > "$KEY_PATH"
    chmod 400 "$KEY_PATH"
    echo "[+] Key saved to $KEY_PATH and permissions set to 400."
else
    echo "[*] Key pair '$KEY_NAME' already exists in AWS."
fi

# 2. Get latest Amazon Linux 2023 AMI
echo "[+] Fetching latest Amazon Linux 2023 AMI ID..."
AMI_ID=$(aws ssm get-parameter --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" --query "Parameter.Value" --output text --region "$REGION")
AZ="${REGION}a"
echo "[+] Using AMI: $AMI_ID in AZ: $AZ"

# 3. Create VPC A
echo "[+] Creating VPC A (10.10.0.0/16)..."
VPC_A_ID=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 --region "$REGION" --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_A_ID" --tags Key=Name,Value=ewb-vpc-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_A_ID" --enable-dns-hostnames "{\"Value\":true}" --region "$REGION"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_A_ID" --enable-dns-support "{\"Value\":true}" --region "$REGION"
echo "    VPC A ID: $VPC_A_ID"

# 4. Create VPC B
echo "[+] Creating VPC B (10.20.0.0/16)..."
VPC_B_ID=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 --region "$REGION" --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_B_ID" --tags Key=Name,Value=ewb-vpc-b Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_B_ID" --enable-dns-hostnames "{\"Value\":true}" --region "$REGION"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_B_ID" --enable-dns-support "{\"Value\":true}" --region "$REGION"
echo "    VPC B ID: $VPC_B_ID"

# 5. Attach Internet Gateway to VPC A
echo "[+] Creating and attaching Internet Gateway to VPC A..."
IGW_A_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources "$IGW_A_ID" --tags Key=Name,Value=ewb-igw-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 attach-internet-gateway --vpc-id "$VPC_A_ID" --internet-gateway-id "$IGW_A_ID" --region "$REGION"
echo "    IGW A ID: $IGW_A_ID"

# 6. Subnets in VPC A
echo "[+] Creating Subnets in VPC A..."
SUBNET_A_PUB=$(aws ec2 create-subnet --vpc-id "$VPC_A_ID" --cidr-block 10.10.1.0/24 --availability-zone "$AZ" --region "$REGION" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_A_PUB" --tags Key=Name,Value=ewb-a-public Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"

SUBNET_A_PRIV=$(aws ec2 create-subnet --vpc-id "$VPC_A_ID" --cidr-block 10.10.2.0/24 --availability-zone "$AZ" --region "$REGION" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_A_PRIV" --tags Key=Name,Value=ewb-a-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"

# 7. Subnet in VPC B
echo "[+] Creating Subnet in VPC B..."
SUBNET_B_PRIV=$(aws ec2 create-subnet --vpc-id "$VPC_B_ID" --cidr-block 10.20.1.0/24 --availability-zone "$AZ" --region "$REGION" --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_B_PRIV" --tags Key=Name,Value=ewb-b-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"

# 8. Route Tables
echo "[+] Creating Route Tables & Associations..."
RT_A_PUB=$(aws ec2 create-route-table --vpc-id "$VPC_A_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$RT_A_PUB" --tags Key=Name,Value=ewb-rt-a-public Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$SUBNET_A_PUB" --route-table-id "$RT_A_PUB" --region "$REGION" > /dev/null
aws ec2 create-route --route-table-id "$RT_A_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_A_ID" --region "$REGION" > /dev/null

RT_A_PRIV=$(aws ec2 create-route-table --vpc-id "$VPC_A_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$RT_A_PRIV" --tags Key=Name,Value=ewb-rt-a-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$SUBNET_A_PRIV" --route-table-id "$RT_A_PRIV" --region "$REGION" > /dev/null

RT_B_PRIV=$(aws ec2 create-route-table --vpc-id "$VPC_B_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$RT_B_PRIV" --tags Key=Name,Value=ewb-rt-b-private Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 associate-route-table --subnet-id "$SUBNET_B_PRIV" --route-table-id "$RT_B_PRIV" --region "$REGION" > /dev/null

# 9. Security Groups
echo "[+] Creating Security Groups and Inbound Rules..."
SG_BASTION=$(aws ec2 create-security-group --group-name ewb-sg-bastion --description "Bastion Host SG" --vpc-id "$VPC_A_ID" --region "$REGION" --query 'GroupId' --output text)
aws ec2 create-tags --resources "$SG_BASTION" --tags Key=Name,Value=ewb-sg-bastion Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_BASTION" --protocol tcp --port 22 --cidr "$MY_CIDR" --region "$REGION" > /dev/null

SG_APP_A=$(aws ec2 create-security-group --group-name ewb-sg-app-a --description "App A SG" --vpc-id "$VPC_A_ID" --region "$REGION" --query 'GroupId' --output text)
aws ec2 create-tags --resources "$SG_APP_A" --tags Key=Name,Value=ewb-sg-app-a Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_A" --protocol tcp --port 22 --cidr 10.10.1.10/32 --region "$REGION" > /dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_A" --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.20.1.10/32}]" --region "$REGION" > /dev/null

SG_APP_B=$(aws ec2 create-security-group --group-name ewb-sg-app-b --description "App B SG" --vpc-id "$VPC_B_ID" --region "$REGION" --query 'GroupId' --output text)
aws ec2 create-tags --resources "$SG_APP_B" --tags Key=Name,Value=ewb-sg-app-b Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --protocol tcp --port 22 --cidr 10.10.1.10/32 --region "$REGION" > /dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_APP_B" --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]" --region "$REGION" > /dev/null

# 10. Launch EC2 Instances
echo "[+] Launching EC2 instances with static private IPs..."
# Bastion
INST_BASTION=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_BASTION" \
    --subnet-id "$SUBNET_A_PUB" \
    --private-ip-address 10.10.1.10 \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-bastion},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$STUDENT_NAME}]" \
    --region "$REGION" \
    --query 'Instances[0].InstanceId' --output text)

# App-A
INST_APP_A=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_APP_A" \
    --subnet-id "$SUBNET_A_PRIV" \
    --private-ip-address 10.10.2.10 \
    --no-associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-a},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$STUDENT_NAME}]" \
    --region "$REGION" \
    --query 'Instances[0].InstanceId' --output text)

# App-B
INST_APP_B=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_APP_B" \
    --subnet-id "$SUBNET_B_PRIV" \
    --private-ip-address 10.20.1.10 \
    --no-associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-b},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$STUDENT_NAME}]" \
    --region "$REGION" \
    --query 'Instances[0].InstanceId' --output text)

echo "    Waiting for instances to enter 'running' state..."
aws ec2 wait instance-running --instance-ids "$INST_BASTION" "$INST_APP_A" "$INST_APP_B" --region "$REGION"

BASTION_PUB_IP=$(aws ec2 describe-instances --instance-ids "$INST_BASTION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region "$REGION")

# 11. Create VPC Peering
echo "[+] Establishing VPC Peering Connection between VPC A and VPC B..."
PCX_ID=$(aws ec2 create-vpc-peering-connection --vpc-id "$VPC_A_ID" --peer-vpc-id "$VPC_B_ID" --region "$REGION" --query 'VpcPeeringConnection.VpcPeeringConnectionId' --output text)
aws ec2 create-tags --resources "$PCX_ID" --tags Key=Name,Value=ewb-a-b-peer Key=Project,Value=EWB-VPC-Peering Key=Student,Value="$STUDENT_NAME" --region "$REGION"
echo "    Accepting Peering Connection $PCX_ID..."
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id "$PCX_ID" --region "$REGION" > /dev/null

# 12. Add Peering Routes
echo "[+] Adding Peering Routes to Route Tables..."
aws ec2 create-route --route-table-id "$RT_A_PRIV" --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "$PCX_ID" --region "$REGION" > /dev/null
aws ec2 create-route --route-table-id "$RT_B_PRIV" --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id "$PCX_ID" --region "$REGION" > /dev/null
aws ec2 create-route --route-table-id "$RT_A_PUB" --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id "$PCX_ID" --region "$REGION" > /dev/null

# 13. Save Metadata
cat << EOF > lab_resources.json
{
  "region": "$REGION",
  "student": "$STUDENT_NAME",
  "vpc_a_id": "$VPC_A_ID",
  "vpc_b_id": "$VPC_B_ID",
  "igw_a_id": "$IGW_A_ID",
  "pcx_id": "$PCX_ID",
  "subnet_a_public_id": "$SUBNET_A_PUB",
  "subnet_a_private_id": "$SUBNET_A_PRIV",
  "subnet_b_private_id": "$SUBNET_B_PRIV",
  "rt_a_public_id": "$RT_A_PUB",
  "rt_a_private_id": "$RT_A_PRIV",
  "rt_b_private_id": "$RT_B_PRIV",
  "sg_bastion_id": "$SG_BASTION",
  "sg_app_a_id": "$SG_APP_A",
  "sg_app_b_id": "$SG_APP_B",
  "bastion_instance_id": "$INST_BASTION",
  "bastion_public_ip": "$BASTION_PUB_IP",
  "app_a_instance_id": "$INST_APP_A",
  "app_b_instance_id": "$INST_APP_B"
}
EOF

echo "=========================================================="
echo " Deployment Complete! Resources saved to lab_resources.json"
echo " Bastion Public IP: $BASTION_PUB_IP"
echo ""
echo " Append the following to your ~/.ssh/config:"
echo "----------------------------------------------------------"
cat << SSHCONF
Host ewb-bastion
  HostName $BASTION_PUB_IP
  User ec2-user
  IdentityFile ~/.ssh/ewb-lab.pem
  IdentitiesOnly yes

Host ewb-app-a
  HostName 10.10.2.10
  User ec2-user
  IdentityFile ~/.ssh/ewb-lab.pem
  IdentitiesOnly yes
  ProxyJump ewb-bastion

Host ewb-app-b
  HostName 10.20.1.10
  User ec2-user
  IdentityFile ~/.ssh/ewb-lab.pem
  IdentitiesOnly yes
  ProxyJump ewb-bastion
SSHCONF
echo "----------------------------------------------------------"
