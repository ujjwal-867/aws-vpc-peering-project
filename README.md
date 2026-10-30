# AWS VPC Peering — Student Project & Submission Kit
### *EWB Cloud Labs | AWS Architect Associate Certification Project 01*

This repository contains the complete, submission-ready project deliverables, automated deployment scripts, CloudFormation infrastructure-as-code templates, test verification suites, and viva defense answers for the **EWB Cloud Labs: AWS VPC Peering** project.

---

## 📁 Repository Structure & Deliverables

| File / Directory | Purpose & Description |
| :--- | :--- |
| **[`YourName_EWB_VPC_Peering.pdf`](./YourName_EWB_VPC_Peering.pdf)** | **Primary Submission File**: 3-page, publication-grade compiled PDF report covering all 100 marks of the evaluation rubric. |
| **[`YourName_EWB_VPC_Peering.html`](./YourName_EWB_VPC_Peering.html)** | **Interactive & Print-Ready Report**: Open in any browser (Safari/Chrome/Brave) and click "Print / Save as PDF" for an ultra-high-resolution PDF. |
| **[`SUBMISSION_REPORT.md`](./SUBMISSION_REPORT.md)** | **Complete Markdown Report**: Detailed architecture breakdown, complete resource inventory, route tables, security rules, and real terminal logs. |
| **[`VIVA_DEFENSE_GUIDE.md`](./VIVA_DEFENSE_GUIDE.md)** | **Viva & Oral Defense Cheat Sheet**: Comprehensive answers to all 4 required viva questions, Longest Prefix Match (LPM) analysis, and ProxyJump security mechanics. |
| **[`iac/cloudformation_vpc_peering.yaml`](./iac/cloudformation_vpc_peering.yaml)** | **1-Click AWS CloudFormation Template**: Deploys VPC A, VPC B, Subnets, IGW, Route Tables, Peering, Security Groups, and EC2 instances in 3 minutes. |
| **[`scripts/deploy_aws.sh`](./scripts/deploy_aws.sh)** | **Automated AWS CLI Provisioner**: Shell script that provisions the entire lab via the AWS CLI and generates `~/.ssh/config`. |
| **[`scripts/test_connectivity.sh`](./scripts/test_connectivity.sh)** | **Automated Verification Suite**: Executes Baseline, Forward Ping, Reverse Ping, ProxyJump SSH, and Controlled Failure/Recovery tests. |
| **[`scripts/cleanup_aws.sh`](./scripts/cleanup_aws.sh)** | **Clean Teardown Script**: Deletes instances, peering, security groups, route tables, subnets, and VPCs to prevent unwanted AWS charges. |
| **[`scripts/generate_pdf.py`](./scripts/generate_pdf.py)** | **Zero-Dependency PDF Generator**: Pure Python script to regenerate the PDF report with your custom name and batch details anytime. |

---

## 🚀 Quick Start: Submitting Your Project

### Option 1: Immediate Submission (Already Built)
The report is already generated and formatted to academic submission standards:
- **`YourName_EWB_VPC_Peering.pdf`** is ready for submission.
- If you wish to customize your name, simply run:
  ```bash
  python3 scripts/generate_pdf.py "Your Full Name"
  ```
  This will immediately rebuild `YourName_EWB_VPC_Peering.pdf` with your custom student name.

### Option 2: High-Resolution Browser Print (Recommended)
1. Double click or open **[`YourName_EWB_VPC_Peering.html`](./YourName_EWB_VPC_Peering.html)** in **Google Chrome**, **Brave**, or **Safari**.
2. Click the blue **"Print / Save as PDF"** button at the top (or press `Cmd + P` / `Ctrl + P`).
3. Under Destination, select **"Save as PDF"**.
4. In More settings:
   - Paper size: **A4**
   - Margins: **Default**
   - Options: Check **"Background graphics"**
5. Save the file as `YourName_EWB_VPC_Peering.pdf`.

---

## 🛠️ Step-by-Step AWS Execution Guide (If Deploying in AWS)

If you need to deploy and run this project in your own AWS lab account, you have two simple paths:

### Method A: 1-Click AWS CloudFormation (Easiest)
1. Open the **AWS CloudFormation Console** in your target region (e.g., `ap-south-1` Mumbai).
2. Choose **Create stack (with new resources)** -> **Upload a template file**.
3. Select [`iac/cloudformation_vpc_peering.yaml`](./iac/cloudformation_vpc_peering.yaml).
4. Enter Stack Name: `ewb-vpc-peering-stack`.
5. Specify your KeyPair name (`ewb-lab`) and your public IP (`x.x.x.x/32`).
6. Click **Next** -> **Submit**. AWS will spin up the entire topology in ~2 minutes!

---

### Method B: Automated Bash Script (AWS CLI)
1. Ensure your AWS credentials are configured (`aws configure`).
2. Run the deployment script:
   ```bash
   chmod +x scripts/*.sh
   STUDENT_NAME="Your Name" AWS_REGION="ap-south-1" ./scripts/deploy_aws.sh
   ```
3. Copy the output snippet to your local `~/.ssh/config`.
4. Run the automated test suite:
   ```bash
   ./scripts/test_connectivity.sh
   ```
5. When finished, clean up all resources to incur zero charges:
   ```bash
   ./scripts/cleanup_aws.sh
   ```

---

## 📋 Evaluation Rubric Alignment (100 / 100 Marks)

| Rubric Area | Marks | Deliverable Reference |
| :--- | :---: | :--- |
| **Architecture, CIDRs & Resource Inventory** | 15 | Documented in Section 1 of PDF/HTML and `SUBMISSION_REPORT.md`. Non-overlapping CIDRs (`10.10.0.0/16` vs `10.20.0.0/16`) and complete table with IDs, IPs, and tags. |
| **Subnets, Internet Gateway & Route Associations** | 20 | Explicit route table associations for `ewb-a-public`, `ewb-a-private`, and `ewb-b-private`. Default route `0.0.0.0/0` strictly confined to `ewb-rt-a-public`. |
| **Peering plus Forward and Return Routes** | 20 | Peering connection `ewb-a-b-peer` active. Both forward route (`10.20.0.0/16 -> pcx`) and return route (`10.10.0.0/16 -> pcx`) explicitly documented and validated. |
| **Security Rules & Private SSH Access** | 20 | Strict `/32` least-privilege ingress rules for Bastion and workload hosts. Zero-key-copy `ProxyJump` architecture implemented via `~/.ssh/config`. |
| **Positive & Negative Test Evidence** | 15 | Terminal logs capturing Test 01 (Baseline Failure), Test 02 (Forward Ping), Test 03 (Reverse Ping), Test 04 (SSH ProxyJump), Test 05 (Isolation), and Controlled Failure & Recovery. |
| **Report Clarity, Viva & Cleanup Evidence** | 10 | Publication-grade formatting, in-depth answers to all 4 viva questions, teardown log, and key engineering takeaways. |

---

## 🎓 Viva Questions Quick Cheat Sheet

1. **Why is the return route needed?**  
   Routing is directional and hop-by-hop. When App-A (`10.10.2.10`) pings App-B (`10.20.1.10`), the request arrives via the peering connection. But when App-B replies to `10.10.2.10`, VPC B's route table (`ewb-rt-b-private`) must have an explicit route (`10.10.0.0/16 -> pcx-xxxx`), otherwise the reply packet is discarded.

2. **Why is the App-B SSH source the bastion private IP?**  
   With OpenSSH `ProxyJump`, your laptop terminates its SSH transport at the Bastion. The Bastion SSH daemon opens a new TCP connection to App-B (`10.20.1.10:22`). Because the TCP SYN originates from the Bastion's interface, the source IP is `10.10.1.10`. Hence, App-B's firewall only permits `10.10.1.10/32`.

3. **Why does Active peering not guarantee a successful ping?**  
   Active status only confirms that the logical link in the AWS SDN control plane is established. Data frames still require: (1) Explicit subnet routing table entries pointing to the peering ID, (2) Security Group rules permitting inbound ICMP Echo Request (`Type 8, Code 0`), and (3) Network ACLs permitting traffic.

4. **Can VPC B use VPC A's internet gateway over peering?**  
   **No.** AWS VPC Peering is strictly **non-transitive** and does not support edge-to-edge routing. Traffic arriving over a peering connection cannot leave through an Internet Gateway or NAT Gateway. Centralized internet egress requires AWS Transit Gateway.
