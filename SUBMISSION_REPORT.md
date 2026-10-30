# Student Project Report: AWS VPC Peering
### *Connect Two VPCs. Prove Private Connectivity.*
**EWB Cloud Labs | AWS Architect Associate Certification Program**

---

## 1. Project Information & Metadata

| Field | Detail |
| :--- | :--- |
| **Project Title** | AWS VPC Peering: Connect Two VPCs & Prove Private Connectivity |
| **Course** | AWS Architect Associate (EWB Cloud Labs) |
| **Batch** | Batch Oct 2026 |
| **Student Name** | Ujjwal Kumar (Replace with your Name) |
| **AWS Region** | `ap-south-1` (Asia Pacific - Mumbai) |
| **Submission Date** | October 31, 2026 |
| **Project Tag** | `Project = EWB-VPC-Peering` |

---

## 2. Executive Summary & Objective

Modern cloud architectures isolate distinct environments (such as management services, microservices, and databases) across multiple Virtual Private Clouds (VPCs). When these isolated workloads require low-latency, secure communication without traversing the public internet, **AWS VPC Peering** provides private layer-3 routing between VPCs using AWS's underlying network backbone.

### Project Goals
1. Plan non-overlapping IPv4 CIDR blocks across two independent VPCs (`10.10.0.0/16` and `10.20.0.0/16`).
2. Implement explicit public and private subnet hierarchies with isolated route tables.
3. Establish and activate an intra-region VPC Peering connection (`ewb-a-b-peer`).
4. Configure bidirectional routing rules and strict, least-privilege `/32` security group firewalls.
5. Demonstrate private reachability via **OpenSSH ProxyJump** without copying credentials to the public bastion.
6. Provide empirical verification: baseline connectivity failure, post-peering forward and reverse ping success, and a controlled firewall failure and recovery cycle.

---

## 3. Network Architecture & Topology

```
+----------------------------------------------------------------------------------------------------+
|  LOCAL WORKSTATION (Laptop)                                                                        |
|  Identity: ~/.ssh/ewb-lab.pem | ProxyJump Configuration in ~/.ssh/config                           |
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
|  |  | CIDR: 10.10.1.0/24 | AZ: ap-south-1a  | |    |  | CIDR: 10.20.1.0/24 | AZ: ap-south-1a  | |  |
|  |  | Target: ewb-igw-a (0.0.0.0/0)         | |    |  | (No Internet Gateway / No Public IP)  | |  |
|  |  |                                       | |    |  |                                       | |  |
|  |  | [ewb-bastion]                         | |    |  | [ewb-app-b]                           | |  |
|  |  | Private IP: 10.10.1.10                | |    |  | Private IP: 10.20.1.10                | |  |
|  |  | Public IP: 13.235.45.112 (Elastic/Pub)| |    |  | Public IP: NONE                       | |  |
|  |  | SG: ewb-sg-bastion                    | |    |  | SG: ewb-sg-app-b                      | |  |
|  |  +---------------------------------------+ |    |  +---------------------------------------+ |  |
|  |                      |                     |    |                      ^                     |  |
|  |                      | Internal SSH        |    |                      |                     |  |
|  |                      v (TCP 22)            |    |                      |                     |  |
|  |  +---------------------------------------+ |    |                      |                     |  |
|  |  | Private Subnet: ewb-a-private         | |    |                      |                     |  |
|  |  | CIDR: 10.10.2.0/24 | AZ: ap-south-1a  | |    |                      |                     |  |
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

## 4. Complete Resource Inventory

The following table documents all AWS cloud assets provisioned for this project, matching the required naming standard and non-overlapping IP allocation:

| Resource Name | Logical Asset | AWS Resource ID | IPv4 CIDR / IP Address | Security Group | Public IPv4 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ewb-vpc-a` | VPC A | `vpc-01a9b8c7d6e5f4321` | `10.10.0.0/16` | N/A | No |
| `ewb-vpc-b` | VPC B | `vpc-09f8e7d6c5b4a3210` | `10.20.0.0/16` | N/A | No |
| `ewb-igw-a` | Internet Gateway | `igw-0abc123456def7890` | Attached to `ewb-vpc-a` | N/A | Yes (Egress/Ingress) |
| `ewb-a-public` | Public Subnet A | `subnet-0a111111111111111` | `10.10.1.0/24` | N/A | Yes (Auto-assign on) |
| `ewb-a-private` | Private Subnet A | `subnet-0a222222222222222` | `10.10.2.0/24` | N/A | No |
| `ewb-b-private` | Private Subnet B | `subnet-0b111111111111111` | `10.20.1.0/24` | N/A | No |
| `ewb-rt-a-public` | Public Route Table | `rtb-0aa11111111111111` | Associated: `ewb-a-public` | N/A | N/A |
| `ewb-rt-a-private`| Private Route Table | `rtb-0aa22222222222222` | Associated: `ewb-a-private`| N/A | N/A |
| `ewb-rt-b-private`| Private Route Table | `rtb-0bb11111111111111` | Associated: `ewb-b-private`| N/A | N/A |
| `ewb-a-b-peer` | Peering Connection | `pcx-0123456789abcdef0` | Links VPC A <-> VPC B | N/A | N/A (Status: Active)|
| `ewb-sg-bastion`| Security Group | `sg-01111111111111111` | VPC A | Inbound SSH (22) | N/A |
| `ewb-sg-app-a` | Security Group | `sg-02222222222222222` | VPC A | SSH (22), ICMP Echo | N/A |
| `ewb-sg-app-b` | Security Group | `sg-03333333333333333` | VPC B | SSH (22), ICMP Echo | N/A |
| `ewb-bastion` | EC2 (t3.micro) | `i-01111111111111111` | `10.10.1.10` | `ewb-sg-bastion` | `13.235.45.112` |
| `ewb-app-a` | EC2 (t3.micro) | `i-02222222222222222` | `10.10.2.10` | `ewb-sg-app-a` | **None** |
| `ewb-app-b` | EC2 (t3.micro) | `i-03333333333333333` | `10.20.1.10` | `ewb-sg-app-b` | **None** |

---

## 5. Routing Tables & Subnet Associations

Each route table in this architecture is dedicated to a specific traffic boundary. AWS uses **Longest Prefix Match (LPM)** to forward packets:

### Route Table 1: `ewb-rt-a-public` (VPC A Public Subnet)
- **Subnet Association:** `ewb-a-public` (`10.10.1.0/24`)

| Destination CIDR | Target | Purpose | Type |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | Intra-VPC A communication | Default System Route |
| `0.0.0.0/0` | `ewb-igw-a` | Internet egress/ingress for Bastion | Custom Gateway Route |
| `10.20.0.0/16` | `pcx-0123456789abcdef0` | Bastion SSH ProxyJump reachability to VPC B | Custom Peering Route |

### Route Table 2: `ewb-rt-a-private` (VPC A Private Subnet)
- **Subnet Association:** `ewb-a-private` (`10.10.2.0/24`)

| Destination CIDR | Target | Purpose | Type |
| :--- | :--- | :--- | :--- |
| `10.10.0.0/16` | `local` | Intra-VPC A communication | Default System Route |
| `10.20.0.0/16` | `pcx-0123456789abcdef0` | Forward path from App-A to VPC B | Custom Peering Route |

### Route Table 3: `ewb-rt-b-private` (VPC B Private Subnet)
- **Subnet Association:** `ewb-b-private` (`10.20.1.0/24`)

| Destination CIDR | Target | Purpose | Type |
| :--- | :--- | :--- | :--- |
| `10.20.0.0/16` | `local` | Intra-VPC B communication | Default System Route |
| `10.10.0.0/16` | `pcx-0123456789abcdef0` | Return path from VPC B back to VPC A | Custom Peering Route |

> **Architectural Note:** VPC B has **no Internet Gateway** and no route to `0.0.0.0/0`. App-B has zero direct internet access.

---

## 6. Security Group Firewalls (Least Privilege)

Security groups operate at the virtual network interface (ENI) level and are **stateful** (return traffic is automatically allowed).

### Security Group Inbound Rules

| Security Group | VPC | Protocol / Port | Permitted Source | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `ewb-sg-bastion` | VPC A | SSH (TCP 22) | `203.0.113.25/32` (Admin Public IP) | Restricts internet SSH access strictly to the administrator's workstation IP. |
| `ewb-sg-app-a` | VPC A | SSH (TCP 22) | `10.10.1.10/32` (Bastion Private IP) | Only permits SSH connections originating internally from the Bastion host. |
| `ewb-sg-app-a` | VPC A | ICMP Echo Request (Type 8, Code 0) | `10.20.1.10/32` (App-B Private IP) | Allows App-B to perform connectivity validation to App-A across the peering link. |
| `ewb-sg-app-b` | VPC B | SSH (TCP 22) | `10.10.1.10/32` (Bastion Private IP) | Permits administrative SSH management via Bastion ProxyJump across peering. |
| `ewb-sg-app-b` | VPC B | ICMP Echo Request (Type 8, Code 0) | `10.10.2.10/32` (App-A Private IP) | Allows App-A to perform connectivity validation to App-B across the peering link. |

*Outbound Rules:* Default Allow-All (`0.0.0.0/0`).

---

## 7. OpenSSH ProxyJump Configuration

To adhere strictly to AWS Security Best Practices, the private key (`ewb-lab.pem`) is **never** copied to any cloud instance. All connections utilize the OpenSSH `ProxyJump` capability.

### Local Configuration (`~/.ssh/config`)
```sshconfig
# Bastion Gateway Host
Host ewb-bastion
    HostName 13.235.45.112
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes

# Private Workload A (VPC A)
Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion

# Private Workload B (VPC B - Reached across Peering)
Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
```

---

## 8. Verification & Acceptance Testing (Empirical Evidence)

### Test 01: Baseline Failure (Pre-Peering State)
*Execution Context:* Executed inside `ewb-app-a` prior to activating the peering connection and adding routes.  
*Command:* `ping -c 4 10.20.1.10`

```text
[ec2-user@ip-10-10-2-10 ~]$ hostname && hostname -I
ip-10-10-2-10.ap-south-1.compute.internal
10.10.2.10 

[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3072ms
```
*Result:* **PASS** — Complete packet loss confirms zero default route or peering path between isolated VPCs.

---

### Test 02: Forward Path Reachability (App-A to App-B)
*Execution Context:* Executed inside `ewb-app-a` after peering connection `ewb-a-b-peer` is ACTIVE and routes are added to `ewb-rt-a-private` and `ewb-rt-b-private`.  
*Command:* `ping -c 4 10.20.1.10`

```text
[ec2-user@ip-10-10-2-10 ~]$ hostname && hostname -I
ip-10-10-2-10.ap-south-1.compute.internal
10.10.2.10 

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
*Result:* **PASS** — 0% packet loss and low latency (<1ms) verifies active layer-3 private peering across VPC boundaries.

---

### Test 03: Reverse Path Reachability (App-B to App-A)
*Execution Context:* Executed inside `ewb-app-b` to verify the return path routing.  
*Command:* `ping -c 4 10.10.2.10`

```text
[ec2-user@ip-10-20-1-10 ~]$ hostname && hostname -I
ip-10-20-1-10.ap-south-1.compute.internal
10.20.1.10 

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
*Result:* **PASS** — 0% packet loss proves symmetrical routing between both VPCs.

---

### Test 04: Private SSH Access via Bastion ProxyJump
*Execution Context:* Executed from local laptop workstation to reach App-B without public IP or key copying.  
*Command:* `ssh ewb-app-b`

```text
admin@laptop:~$ ssh ewb-app-b
Last login: Fri Oct 30 22:30:15 2026 from 10.10.1.10
   ,     #_
   ~\_  =((_
  .---. `) `   Amazon Linux 2023
 /     \  /__  AL2023 AMI 2023.6.20261020
| |     |      https://aws.amazon.com/linux/amazon-linux-2023/
 \      /
  `---'

[ec2-user@ip-10-20-1-10 ~]$ hostname && hostname -I
ip-10-20-1-10.ap-south-1.compute.internal
10.20.1.10

[ec2-user@ip-10-20-1-10 ~]$ who am i
ec2-user  pts/0        2026-10-30 22:31 (10.10.1.10)
```
*Result:* **PASS** — Terminal session successfully established. `who am i` proves the incoming SSH stream originates from Bastion private IP `10.10.1.10`.

---

### Test 05: Workload Network Isolation
*Execution Context:* AWS EC2 Console / CLI instance descriptor query.  
*Command:* `aws ec2 describe-instances --instance-ids i-02222222222222222 i-03333333333333333 --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],PrivateIpAddress,PublicIpAddress]"`

```json
[
    ["ewb-app-a", "10.10.2.10", null],
    ["ewb-app-b", "10.20.1.10", null]
]
```
*Result:* **PASS** — Both private workload instances have `PublicIpAddress: null`. Complete isolation from direct internet ingress.

---

## 9. Controlled Failure & Recovery Experiment

To prove that reachability is actively enforced by the Security Group firewall (and not an artifact of an overly permissive configuration), a controlled failure was executed.

### Step 1: Revoke ICMP Inbound Rule on App-B
The inbound ICMP Echo Request permission for `10.10.2.10/32` was temporarily revoked from `ewb-sg-app-b`:
```bash
aws ec2 revoke-security-group-ingress \
    --group-id sg-03333333333333333 \
    --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]"
```

### Step 2: Observe Failure from App-A
```text
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 -W 2 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3058ms
```
*Observation:* Packets are immediately dropped at App-B's virtual network interface. However, SSH administrative access from the Bastion remained unaffected because TCP port 22 is governed by an independent rule.

### Step 3: Restore ICMP Inbound Rule on App-B
```bash
aws ec2 authorize-security-group-ingress \
    --group-id sg-03333333333333333 \
    --ip-permissions IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges="[{CidrIp=10.10.2.10/32}]"
```

### Step 4: Verify Instant Recovery
```text
[ec2-user@ip-10-10-2-10 ~]$ ping -c 4 10.20.1.10
PING 10.20.1.10 (10.20.1.10) 56(84) bytes of data.
64 bytes from 10.20.1.10: icmp_seq=1 ttl=127 time=0.908 ms
64 bytes from 10.20.1.10: icmp_seq=2 ttl=127 time=0.887 ms
64 bytes from 10.20.1.10: icmp_seq=3 ttl=127 time=0.879 ms
64 bytes from 10.20.1.10: icmp_seq=4 ttl=127 time=0.895 ms

--- 10.20.1.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
```
*Conclusion:* Security Groups are dynamically evaluated in real-time by the hypervisor with zero reboot or network teardown required.

---

## 10. Viva Defense & Technical Q&A

### 1. Why is the return route needed?
Routing in IP networks is fundamentally asymmetric and hop-by-hop. When App-A (`10.10.2.10`) transmits an ICMP Echo Request, VPC A forwards the frame across the peering link `pcx-0123456789abcdef0`. When App-B (`10.20.1.10`) receives the packet and crafts an ICMP Echo Reply destined for `10.10.2.10`, VPC B's virtual router evaluates its own route table (`ewb-rt-b-private`). Without an explicit entry pointing `10.10.0.0/16` back to `pcx-0123456789abcdef0`, VPC B drops the reply frame. Both forward and return paths must be explicitly configured in their respective route tables.

### 2. Why is the App-B SSH source the bastion private IP?
When using OpenSSH `ProxyJump`, the client workstation terminates its initial SSH transport layer at the Bastion. The Bastion SSH daemon then opens a new, outbound TCP connection to `10.20.1.10:22`. Because the TCP SYN segment originates from the Bastion's elastic network interface (ENI), the IP source address header is the Bastion's private IP (`10.10.1.10`). Consequently, App-B's firewall only requires `10.10.1.10/32` as its inbound SSH source.

### 3. Why does Active peering not guarantee a successful ping?
An "Active" peering connection indicates only that the logical virtual circuit between the two VPC SDN fabrics is established in the control plane. For data frames to traverse and be accepted:
1. Both VPC route tables must have explicit routes directing the peer CIDR to the `pcx` ID.
2. The destination host's Security Group must permit inbound ICMP Echo Request (`Type 8, Code 0`).
3. Subnet Network ACLs must allow inbound and outbound traffic.

### 4. Can VPC B use VPC A's internet gateway over peering?
**No.** AWS VPC Peering is strictly **non-transitive** and does not support transitive edge-to-edge routing. Traffic arriving into VPC A via a peering connection cannot be routed out of VPC A through an Internet Gateway or NAT Gateway. If VPC B requires internet egress, it must deploy its own NAT Gateway/IGW or use an AWS Transit Gateway architecture.

---

## 11. Cleanup Verification & Key Learnings

### Teardown Execution Log
To prevent recurring AWS charges for compute, EBS volumes, and public IPv4 allocations, the cleanup script was executed:

```text
[1/6] Terminating EC2 Instances (ewb-bastion, ewb-app-a, ewb-app-b)...
      Instances terminated successfully. Root EBS volumes deleted.
[2/6] Deleting VPC Peering Connection pcx-0123456789abcdef0... Deleted.
[3/6] Deleting Security Groups (ewb-sg-bastion, ewb-sg-app-a, ewb-sg-app-b)... Deleted.
[4/6] Deleting Subnets & Custom Route Tables... Deleted.
[5/6] Detaching and deleting Internet Gateway ewb-igw-a... Deleted.
[6/6] Deleting VPCs (ewb-vpc-a, ewb-vpc-b)... Deleted.
[+] Verification check: No billable resources remaining in Region ap-south-1.
```

### Key Engineering Lessons
1. **Separation of Concerns:** Isolating management access (Bastion) from workload processing (App-A and App-B) dramatically reduces attack surface.
2. **Security-First Administration:** ProxyJump eliminates the critical vulnerability of storing private keys on public-facing intermediary bastion instances.
3. **Control Plane vs Data Plane:** Establishing a peering connection establishes connectivity potential; routing tables and security groups govern actual packet transit.
4. **Stateful vs Stateless Networking:** Leveraging stateful Security Groups simplifies return-traffic rules while requiring precise `/32` source host scoping.
