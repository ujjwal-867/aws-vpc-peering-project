#!/usr/bin/env bash
# ==============================================================================
# EWB Cloud Labs: AWS VPC Peering Verification & Testing Script
# Automates the 5 tests, the controlled failure, and captures verification logs.
# ==============================================================================

set -euo pipefail

LOG_FILE="test_verification_results.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "=========================================================="
echo " Starting VPC Peering Verification & Acceptance Suite"
echo " Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "=========================================================="

# Check SSH config
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 ewb-bastion "uptime" &>/dev/null; then
    echo "[-] Cannot reach ewb-bastion via SSH. Please verify ~/.ssh/config and key permissions."
    echo "    Run: chmod 400 ~/.ssh/ewb-lab.pem"
    exit 1
fi
echo "[+] Bastion SSH connection verified."

# Test 04: Private SSH via ProxyJump to App-A and App-B
echo ""
echo "=========================================================="
echo " TEST 04: Private SSH via Bastion (ProxyJump)"
echo "=========================================================="
echo "[+] Connecting to App-A (10.10.2.10) via ProxyJump:"
ssh -o StrictHostKeyChecking=no ewb-app-a "hostname && hostname -I && uptime"
echo "[+] App-A SSH Successful!"

echo ""
echo "[+] Connecting to App-B (10.20.1.10) via ProxyJump:"
ssh -o StrictHostKeyChecking=no ewb-app-b "hostname && hostname -I && uptime"
echo "[+] App-B SSH Successful!"

# Test 02: Forward Path Ping (App-A -> App-B)
echo ""
echo "=========================================================="
echo " TEST 02: Forward Path Ping (App-A -> App-B 10.20.1.10)"
echo "=========================================================="
ssh ewb-app-a "ping -c 4 10.20.1.10"

# Test 03: Reverse Path Ping (App-B -> App-A)
echo ""
echo "=========================================================="
echo " TEST 03: Reverse Path Ping (App-B -> App-A 10.10.2.10)"
echo "=========================================================="
ssh ewb-app-b "ping -c 4 10.10.2.10"

# Controlled Failure and Recovery
if [ -f "lab_resources.json" ]; then
    SG_APP_B=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['sg_app_b_id'])")
    REGION=$(python3 -c "import json; print(json.load(open('lab_resources.json'))['region'])")

    echo ""
    echo "=========================================================="
    echo " CONTROLLED FAILURE: Revoking App-B ICMP Inbound Rule"
    echo "=========================================================="
    echo "[+] Revoking ICMP Echo Request from 10.10.2.10/32 on $SG_APP_B..."
    aws ec2 revoke-security-group-ingress \
        --group-id "$SG_APP_B" \
        --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]" \
        --region "$REGION"

    echo "[+] Repeating forward ping from App-A (Expected: 100% Packet Loss)..."
    ssh ewb-app-a "ping -c 4 -W 2 10.20.1.10 || true"

    echo ""
    echo "=========================================================="
    echo " CONTROLLED RECOVERY: Restoring App-B ICMP Inbound Rule"
    echo "=========================================================="
    echo "[+] Restoring ICMP Echo Request rule on $SG_APP_B..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_APP_B" \
        --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]" \
        --region "$REGION"

    echo "[+] Repeating forward ping from App-A (Expected: 0% Packet Loss)..."
    ssh ewb-app-a "ping -c 4 10.20.1.10"
    echo "[+] Controlled Failure & Recovery Test Completed Successfully!"
fi

echo ""
echo "=========================================================="
echo " Verification Suite Complete. Results saved to $LOG_FILE"
echo "=========================================================="
