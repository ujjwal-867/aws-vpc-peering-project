# EWB Cloud Labs: AWS VPC Peering — Viva Defense & Architecture Guide

This comprehensive reference is designed to prepare you for technical interviews, viva defense, and evaluator evaluations for the **AWS Architect Associate: VPC Peering Project**.

---

## 1. Core Viva Questions & Expert Answers

### Q1: Why is the return route needed?
**Evaluation Focus:** Understanding L3 IP routing, asymmetric routing, and AWS VPC route table evaluation.

* **Direct Answer:**  
  IP routing is hop-by-hop and directional. When an instance in VPC A (`10.10.2.10`) sends an ICMP Echo Request to VPC B (`10.20.1.10`), VPC A's route table forwards the packet across the peering connection (`pcx-xxxx`). Upon receiving the packet, the target instance in VPC B generates an ICMP Echo Reply with destination IP `10.10.2.10`.
* **The Routing Failure Without Return Route:**  
  VPC B evaluates its own subnet route table (`ewb-rt-b-private`). By default, it only contains a local route for `10.20.0.0/16`. Because there is no route matching `10.10.2.10` (or `10.10.0.0/16`), VPC B's virtual router drops the reply packet immediately.
* **Key Takeaway:**  
  A one-way route allows packets to reach the destination, but without an explicit return route (`10.10.0.0/16 -> pcx-xxxx`) in VPC B, bi-directional communication (such as TCP handshakes or ICMP echo replies) cannot occur.

---

### Q2: Why is the App-B SSH source the bastion private IP?
**Evaluation Focus:** OpenSSH `ProxyJump` mechanics vs. NAT vs. direct routing.

* **Direct Answer:**  
  When connecting to App-B from your local workstation using OpenSSH `ProxyJump` (`ssh -J ewb-bastion ec2-user@10.20.1.10`), the connection is established in two independent TCP stages:
  1. **Stage 1 (Client to Bastion):** Your laptop establishes an SSH session with the Bastion's public IP over the Internet Gateway (`0.0.0.0/0 -> igw-a`).
  2. **Stage 2 (Bastion to Target):** The Bastion SSH daemon creates a local TCP socket and opens a brand-new TCP stream directly to App-B's private IP (`10.20.1.10:22`) across the VPC peering connection.
* **Why the Source IP is `10.10.1.10`:**  
  Because the TCP SYN packet to App-B is initiated directly from the Bastion's network interface (`eth0`), the Layer 3 IPv4 source address in the IP header is the Bastion's private IP (`10.10.1.10`), **not** your laptop's public IP.
* **Security Group Consequence:**  
  `ewb-sg-app-b` only needs to allow inbound TCP 22 from `10.10.1.10/32`. It does not require—and should never have—rules allowing external public IP addresses.

---

### Q3: Why does Active peering not guarantee a successful ping?
**Evaluation Focus:** Distinguishing between physical/logical interconnects, routing, and packet filtering (firewalls).

* **Direct Answer:**  
  An **Active** VPC Peering connection only confirms that the logical point-to-point interconnect between the two VPC software-defined networks has been requested and accepted in the AWS control plane. It does **not** configure data-plane forwarding or security permissions.
* **The Three Missing Requirements:**  
  1. **Route Tables:** Neither VPC knows to send traffic destined for the other VPC over the peering connection until explicit route table entries (`10.20.0.0/16 -> pcx-xxxx` and `10.10.0.0/16 -> pcx-xxxx`) are added.
  2. **Security Groups (Stateful Firewalls):** By default, AWS Security Groups drop all unsolicited inbound traffic. Unless the target host's security group explicitly permits inbound **ICMP Echo Request (Type 8, Code 0)** from the sender's IP or CIDR, the packet is silently dropped at the hypervisor virtual interface (ENI).
  3. **Network ACLs / OS Firewalls:** If custom NACLs or host-level firewalls (`iptables`, `nftables`, `firewalld`) are configured, they can also block ICMP traffic.

---

### Q4: Can VPC B use VPC A's internet gateway over peering?
**Evaluation Focus:** VPC Peering non-transitive routing constraint and edge-to-edge routing limitations.

* **Direct Answer:**  
  **No.** AWS VPC Peering is strictly **non-transitive** and does not support transitive routing or edge-to-edge routing.
* **Detailed AWS Rule:**  
  Traffic that enters a VPC via a VPC peering connection cannot be routed out of that VPC via an Internet Gateway, NAT Gateway, Virtual Private Gateway (Direct Connect / VPN), or another peering connection.
* **Production Alternative:**  
  If VPC B needs internet access through VPC A, an **AWS Transit Gateway (TGW)** or a centralized egress VPC architecture with AWS Network Firewall / NAT Gateways must be deployed.

---

## 2. Advanced Architectural Concepts

### Longest Prefix Match (LPM) in AWS Route Tables
In `ewb-rt-a-public`, there are three routes:
- `10.10.0.0/16` -> `local`
- `0.0.0.0/0` -> `ewb-igw-a`
- `10.20.0.0/16` -> `ewb-a-b-peer`

When the Bastion initiates SSH to `10.20.1.10`, AWS evaluates the destination IP against the route table using **Longest Prefix Match (LPM)**:
- `10.20.0.0/16` matches 16 bits.
- `0.0.0.0/0` matches 0 bits.
Since `/16` is more specific than `/0`, AWS forwards the packet directly through the peering connection, never attempting to send private IP traffic out to the Internet Gateway.

---

### Security Groups vs. Network ACLs (NACLs)

| Feature | Security Group (SG) | Network ACL (NACL) |
| :--- | :--- | :--- |
| **Level** | Instance / ENI Level | Subnet Boundary Level |
| **Statefulness** | **Stateful**: If inbound is allowed, outbound reply is automatically allowed regardless of outbound rules. | **Stateless**: Inbound and outbound traffic must be explicitly permitted in both directions (including ephemeral ports 1024–65535). |
| **Rule Order** | Evaluates **all rules** before deciding to allow traffic. Default is deny-all inbound. | Evaluates rules in **numerical order** (lowest number first) until a match is found. |
| **Deny Rules** | Cannot create explicit `DENY` rules (only `ALLOW`). | Supports both `ALLOW` and `DENY` rules. |

---

### Why ProxyJump is Best Practice (No Key Forwarding / Storage)
- **Anti-Pattern:** Copying `ewb-lab.pem` to the Bastion host using `scp`. If the Bastion is compromised, the attacker obtains the master key to every private server in the infrastructure.
- **Best Practice (ProxyJump):** The private key remains exclusively on your local workstation. OpenSSH uses the Bastion purely as a layer-4 stream proxy (`nc` / TCP forwarding), and the cryptographic SSH handshake happens directly end-to-end between your workstation and App-A/App-B.
