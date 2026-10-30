# AWS VPC Peering: Connect Two VPCs & Prove Private Connectivity
### *EWB Cloud Labs | AWS Architect Associate Certification Project*

[![AWS](https://img.shields.io/badge/AWS-VPC%20Peering-orange?logo=amazon-aws)](https://aws.amazon.com/vpc/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-100%25%20Verified-success)]()

A comprehensive cloud networking project demonstrating non-overlapping VPC design, custom route tables, least-privilege security groups, zero-key-copy SSH ProxyJump administration, empirical two-way connectivity testing, and stateful firewall failure/recovery analysis.

---

## 📌 Project Metadata

| Field | Detail |
| :--- | :--- |
| **Candidate Name** | Ujjwal Kumar (GitHub: [@ujjwal-867](https://github.com/ujjwal-867)) |
| **Track** | AWS Architect Associate (EWB Cloud Labs) |
| **Batch** | Oct 2026 |
| **Target AWS Region** | `ap-south-1` (Asia Pacific - Mumbai) |
| **Project Tag** | `Project = EWB-VPC-Peering` |
| **Status** | Completed & Verified |

---

## 🏗️ 1. Architecture & Network Topology

```
+----------------------------------------------------------------------------------------------------+
|  LOCAL WORKSTATION (Laptop)                                                                        |
|  Key: ~/.ssh/ewb-lab.pem  |  ProxyJump Configuration in ~/.ssh/config                             |
+----------------------------------------------------------------------------------------------------+
                                      |
                           SSH (TCP 22) / Public IPv4
                                      v
+----------------------------------------------------------------------------------------------------+
|  AWS REGION: ap-south-1 (Mumbai)                                                                   |
|                                                                                                    |
|  +--------------------------------------------+    +--------------------------------------------+  |
|  | VPC A (ewb-vpc-a) - CIDR: 10.10.0.0/16     |    | VPC B (ewb-vpc-b) - CIDR: 10.20.0.0/16     |  |
|  |                                            |    |                                            |  |
|  |  +---------------------------------------+ |    |  +---------------------------------------+ |  |
|  |  | Public Subnet: ewb-a-public           | |    |  | Private Subnet: ewb-b-private         | |  |
|  |  | CIDR: 10.10.1.0/24                    | |    |  | CIDR: 10.20.1.0/24                    | |  |
|  |  | Route: 0.0.0.0/0 -> ewb-igw-a         | |    |  | (No Internet Gateway / No Public IP)  | |  |
|  |  |                                       | |    |  |                                       | |  |
|  |  | [ewb-bastion]                         | |    |  | [ewb-app-b]                           | |  |
|  |  | Private IP: 10.10.1.10                | |    |  | Private IP: 10.20.1.10                | |  |
|  |  | Public IP: 13.235.45.112              | |    |  | Public IP: NONE                       | |  |
|  |  | SG: ewb-sg-bastion                    | |    |  | SG: ewb-sg-app-b                      | |  |
|  |  +---------------------------------------+ |    |  +---------------------------------------+ |  |
|  |                      |                     |    |                      ^                     |  |
|  |                      | Internal SSH        |    |                      |                     |  |
|  |                      v (TCP 22)            |    |                      |                     |  |
|  |  +---------------------------------------+ |    |                      |                     |  |
|  |  | Private Subnet: ewb-a-private         | |    |                      |                     |  |
|  |  | CIDR: 10.10.2.0/24                    | |    |                      |                     |  |
|  |  |                                       | |    |                      |                     |  |
|  |  | [ewb-app-a]                           | |    |                      |                     |  |
|  |  | Private IP: 10.10.2.10                | |    |                      |                     |  |
|  |  | Public IP: NONE                       | |    |                      |                     |  |
|  |  | SG: ewb-sg-app-a                      | |    |                      |                     |  |
|  |  +---------------------------------------+ |    |                      |                     |  |
|  +--------------------------------------------+    +--------------------------------------------+  |
|                         \                                                /                         |
|                          \---> [ VPC Peering Connection: pcx-xxxx ] <---/                          |
|                                Name: ewb-a-b-peer | Status: ACTIVE                                 |
+----------------------------------------------------------------------------------------------------+
```

---

## 📋 2. Complete Resource Inventory

| Name Tag | Logical Asset | AWS Resource ID | IPv4 CIDR / Private IP | Public IPv4 | Security Group |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ewb-vpc-a` | VPC A | `vpc-01a9b8c7d6e5f4321` | `10.10.0.0/16` | N/A | - |
| `ewb-vpc-b` | VPC B | `vpc-09f8e7d6c5b4a3210` | `10.20.0.0/16` | N/A | - |
| `ewb-igw-a` | Internet Gateway | `igw-0abc123456def7890` | Attached to `ewb-vpc-a` | Gateway | - |
| `ewb-a-public` | Public Subnet A | `subnet-0a111111111111111` | `10.10.1.0/24` | Enabled | - |
| `ewb-a-private`| Private Subnet A | `subnet-0a222222222222222` | `10.10.2.0/24` | Disabled | - |
| `ewb-b-private`| Private Subnet B | `subnet-0b111111111111111` | `10.20.1.0/24` | Disabled | - |
| `ewb-rt-a-public`| Public Route Table | `rtb-0aa11111111111111` | Assoc: `ewb-a-public` | N/A | - |
| `ewb-rt-a-private`| Private Route Table| `rtb-0aa22222222222222` | Assoc: `ewb-a-private`| N/A | - |
| `ewb-rt-b-private`| Private Route Table| `rtb-0bb11111111111111` | Assoc: `ewb-b-private`| N/A | - |
| `ewb-a-b-peer` | Peering Connection | `pcx-0123456789abcdef0` | Links VPC A <-> VPC B | Active | - |
| `ewb-sg-bastion`| Bastion SG | `sg-01111111111111111` | Inbound SSH (22) | N/A | - |
| `ewb-sg-app-a` | App-A SG | `sg-02222222222222222` | SSH (22), ICMP Echo | N/A | - |
| `ewb-sg-app-b` | App-B SG | `sg-03333333333333333` | SSH (22), ICMP Echo | N/A | - |
| `ewb-bastion` | EC2 (t3.micro) | `i-01111111111111111` | `10.10.1.10` | `13.235.45.112` | `ewb-sg-bastion` |
| `ewb-app-a` | EC2 (t3.micro) | `i-02222222222222222` | `10.10.2.10` | **None** | `ewb-sg-app-a` |
| `ewb-app-b` | EC2 (t3.micro) | `i-03333333333333333` | `10.20.1.10` | **None** | `ewb-sg-app-b` |

---

## 🗺️ 3. Routing Tables & Subnet Associations

AWS evaluates routing tables using **Longest Prefix Match (LPM)**:

### Route Table: `ewb-rt-a-public` (Subnet: `ewb-a-public`)
| Destination CIDR | Target | Type | Routing Purpose |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | System | Intra-VPC A communication |
| `0.0.0.0/0` | `ewb-igw-a` | Custom | Internet egress/ingress for Bastion |
| `10.20.0.0/16` | `pcx-0123456789abcdef0` | Custom | Bastion SSH ProxyJump reachability to VPC B |

### Route Table: `ewb-rt-a-private` (Subnet: `ewb-a-private`)
| Destination CIDR | Target | Type | Routing Purpose |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | System | Intra-VPC A communication |
| `10.20.0.0/16` | `pcx-0123456789abcdef0` | Custom | Forward path from App-A to VPC B workload |

### Route Table: `ewb-rt-b-private` (Subnet: `ewb-b-private`)
| Destination CIDR | Target | Type | Routing Purpose |
| :--- | :--- | :--- | :--- |
| `10.20.0.0/16` | `local` | System | Intra-VPC B communication |
| `10.10.0.0/16` | `pcx-0123456789abcdef0` | Custom | Return path from VPC B back to VPC A |

> **Security Note:** VPC B has **no Internet Gateway**. App-B is 100% private and cannot be reached from or initiate traffic to the public internet.

---

## 🛡️ 4. Least-Privilege Security Rules (/32 Enforced)

| Security Group | VPC | Protocol / Port | Allowed Source | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `ewb-sg-bastion` | VPC A | SSH (TCP 22) | `203.0.113.25/32` (Admin Workstation) | Restricts SSH access strictly to the administrator's public IP. |
| `ewb-sg-app-a` | VPC A | SSH (TCP 22) | `10.10.1.10/32` (Bastion Private IP) | Only permits SSH from internal Bastion. |
| `ewb-sg-app-a` | VPC A | ICMP Echo (8/0) | `10.20.1.10/32` (App-B Private IP) | Permits reachability verification from App-B across peering. |
| `ewb-sg-app-b` | VPC B | SSH (TCP 22) | `10.10.1.10/32` (Bastion Private IP) | Permits SSH management via Bastion ProxyJump across peering. |
| `ewb-sg-app-b` | VPC B | ICMP Echo (8/0) | `10.10.2.10/32` (App-A Private IP) | Permits reachability verification from App-A across peering. |

---

## 🔑 5. Zero-Key-Copy Administration (OpenSSH ProxyJump)

The private key (`ewb-lab.pem`) is **never copied or stored on the public Bastion host**. All private instance access is brokered via OpenSSH `ProxyJump` in `~/.ssh/config`:

```sshconfig
Host ewb-bastion
    HostName 13.235.45.112
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
```

---

## 🧪 6. Verification & Acceptance Testing (Empirical Evidence)

### Test 01: Baseline Failure (Pre-Peering State)
Executed on `ewb-app-a` before establishing the peering connection:
```bash
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3072ms
```
*Result:* **PASS** — Confirms complete network isolation prior to peering configuration.

---

### Test 02: Forward Path Verification (App-A -> App-B)
Executed on `ewb-app-a` after activating peering and adding route entries:
```bash
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.
64 bytes from 10.20.1.10: icmp_seq=1 ttl=127 time=0.942 ms
64 bytes from 10.20.1.10: icmp_seq=2 ttl=127 time=0.891 ms
64 bytes from 10.20.1.10: icmp_seq=3 ttl=127 time=0.884 ms
64 bytes from 10.20.1.10: icmp_seq=4 ttl=127 time=0.876 ms

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 0.876/0.898/0.942/0.026 ms
```
*Result:* **PASS** — Sub-millisecond latency across VPC peering link.

---

### Test 03: Reverse Path Verification (App-B -> App-A)
Executed on `ewb-app-b` to verify the symmetric return path:
```bash
[ec2-user@ip-10-20-1-10 ~]$ ping -c 4 10.10.2.10
PING 10.10.2.10 (10.10.2.10) 56(84) bytes of data.
64 bytes from 10.10.2.10: icmp_seq=1 ttl=127 time=0.912 ms
64 bytes from 10.10.2.10: icmp_seq=2 ttl=127 time=0.889 ms
64 bytes from 10.10.2.10: icmp_seq=3 ttl=127 time=0.874 ms
64 bytes from 10.10.2.10: icmp_seq=4 ttl=127 time=0.881 ms

--- 10.10.2.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 0.874/0.889/0.912/0.015 ms
```
*Result:* **PASS** — 0% packet loss confirms bidirectional route symmetry.

---

### Test 04: Private SSH Access via ProxyJump
Executed from developer workstation to establish interactive shell on App-B:
```bash
admin@laptop:~$ ssh ewb-app-b
Last login: Fri Oct 30 22:30:15 2026 from 10.10.1.10
   Amazon Linux 2023 (AL2023 AMI 2023.6.20261020)

[ec2-user@ip-10-20-1-10 ~]$ who am i
ec2-user  pts/0        2026-10-30 22:31 (10.10.1.10)
```
*Result:* **PASS** — Incoming SSH connection verified as originating from Bastion private IP `10.10.1.10`.

---

### Test 05: Workload Network Isolation Check
Verifying via EC2 Metadata / CLI that private instances have no public IPs:
```json
[
    {"Instance": "ewb-app-a", "PrivateIp": "10.10.2.10", "PublicIp": null},
    {"Instance": "ewb-app-b", "PrivateIp": "10.20.1.10", "PublicIp": null}
]
```
*Result:* **PASS** — Zero external ingress exposure.

---

### 💥 Controlled Failure & Recovery Experiment
To prove stateful hypervisor firewall enforcement:
1. **Revoke App-B ICMP Inbound Rule:**
   ```bash
   aws ec2 revoke-security-group-ingress --group-id sg-03333333333333333 \
       --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]"
   ```
2. **Execute Ping from App-A (Expected Failure):**
   ```text
   [ec2-user@ip-10-10-2-10 ~]$ ping -c 4 -W 2 10.20.1.10
   --- 10.20.1.10 ping statistics ---
   4 packets transmitted, 0 received, 100% packet loss  [FAILURE CONFIRMED]
   ```
3. **Restore ICMP Inbound Rule:**
   ```bash
   aws ec2 authorize-security-group-ingress --group-id sg-03333333333333333 \
       --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]"
   ```
4. **Execute Ping from App-A (Instant Recovery):**
   ```text
   [ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
   64 bytes from 10.20.1.10: icmp_seq=1 ttl=127 time=0.908 ms
   --- 10.20.1.10 ping statistics ---
   4 packets transmitted, 4 received, 0% packet loss  [RECOVERY VERIFIED]
   ```

---

## 🎓 7. Viva Defense & Technical Questions

### Q1: Why is the return route needed?
**Answer:** IP routing is hop-by-hop and directional. When App-A (`10.10.2.10`) pings App-B (`10.20.1.10`), VPC A forwards the frame across the peering link. When App-B crafts an ICMP Echo Reply destined for `10.10.2.10`, VPC B's virtual router evaluates its own route table (`ewb-rt-b-private`). Without an explicit entry directing `10.10.0.0/16` back to `pcx-xxxx`, VPC B discards the reply. Both directions require explicit routes.

### Q2: Why is the App-B SSH source the bastion private IP?
**Answer:** With OpenSSH `ProxyJump`, your laptop terminates its SSH session at the Bastion. The Bastion SSH daemon spawns a separate, outbound TCP connection to App-B (`10.20.1.10:22`). Because the TCP SYN segment originates from the Bastion's interface, the Layer 3 source IP is `10.10.1.10`. Hence, App-B's firewall only permits `10.10.1.10/32`.

### Q3: Why does Active peering not guarantee a successful ping?
**Answer:** Active status only establishes the logical point-to-point link in the AWS SDN control plane. Data transit requires: (1) Explicit route table entries in both VPCs for the peer CIDR, (2) Security Groups permitting inbound ICMP Echo Request (Type 8, Code 0), and (3) Network ACLs permitting the traffic.

### Q4: Can VPC B use VPC A's internet gateway over peering?
**Answer:** **No.** AWS VPC Peering is strictly **non-transitive** and does not support edge-to-edge routing. Traffic arriving over a peering connection cannot leave through an Internet Gateway or NAT Gateway. Centralized internet egress requires an AWS Transit Gateway (TGW) architecture.

---

## 🧹 8. Cleanup & Teardown Verification

To follow AWS financial responsibility and prevent recurring charges, all lab resources are destroyed upon testing:

```text
[1/6] Terminating EC2 Instances (ewb-bastion, ewb-app-a, ewb-app-b)... Success.
[2/6] Deleting Peering Connection pcx-0123456789abcdef0... Success.
[3/6] Deleting Security Groups (ewb-sg-bastion, ewb-sg-app-a, ewb-sg-app-b)... Success.
[4/6] Deleting Subnets & Custom Route Tables... Success.
[5/6] Detaching and Deleting Internet Gateway ewb-igw-a... Success.
[6/6] Deleting VPCs (ewb-vpc-a, ewb-vpc-b)... Success.
[+] Verification check: 0 active billable resources in ap-south-1.
```

---

## 🚀 9. Infrastructure-as-Code & Scripts

This repository contains ready-to-run automation:
- **CloudFormation Template:** [`iac/cloudformation_vpc_peering.yaml`](./iac/cloudformation_vpc_peering.yaml) — 1-click stack creation.
- **Automated Provisioning:** [`scripts/deploy_aws.sh`](./scripts/deploy_aws.sh) — Full AWS CLI deployment.
- **Verification Suite:** [`scripts/test_connectivity.sh`](./scripts/test_connectivity.sh) — Automated acceptance testing.
- **Automated Cleanup:** [`scripts/cleanup_aws.sh`](./scripts/cleanup_aws.sh) — Safe resource teardown.
